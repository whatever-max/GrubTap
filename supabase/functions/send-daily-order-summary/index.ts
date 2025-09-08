// supabase/functions/send-daily-order-summary/index.ts
import { serve } from 'https://deno.land/std@0.177.0/http/server.ts'
import { createClient, SupabaseClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { corsHeaders } from '../_shared/cors.ts' // Assuming you have this for CORS if manually invoking

// --- Email Configuration ---
const TARGET_EMAIL = 'godbssam@gmail.com';
const RESEND_API_KEY = Deno.env.get('RESEND_API_KEY'); // SET THIS IN SUPABASE FUNCTION SECRETS
const EMAIL_FROM_ADDRESS = 'summary@yourdomain.com'; // IMPORTANT: Use a verified domain with Resend

// --- Summary Logic Configuration ---
// These are LOCAL EAT times for the cycle boundaries
const SUMMARY_CYCLE_START_HOUR_EAT = 15; // 3 PM EAT
const SUMMARY_CYCLE_START_MINUTE_EAT = 31; // 3:31 PM EAT
const SUMMARY_ORDER_STATUS = 'sent';
const DEFAULT_FLOOR_NUMBER = '06';

interface OrderItem {
  id: string;
  quantity: number;
  // item_price: number; // Assuming not needed for summary text, but present in your DB
  foods: { // Assuming 'foods' is the related table alias from your select
    id: string;
    name: string | null;
  } | null;
}

interface Order {
  id: string;
  order_time: string; // ISO string from DB (UTC)
  status: string | null;
  companies: {
    name: string | null;
  } | null;
  order_items: OrderItem[];
}

/**
 * Calculates the start and end of the relevant summary period in UTC.
 * The period is from yesterday's EAT start marker to today's EAT end marker (just before the start marker).
 * Example: If run on Wed 10:00 AM EAT, period is Mon 3:31 PM EAT to Tue 3:29 PM EAT (if start is 3:31PM)
 * More accurately: if run on Wed 10:00 AM EAT, the summary is for orders from
 * Tue 3:31 PM EAT to Wed 3:29 PM EAT.
 */
function getRelevantSummaryPeriodUTC(nowUtc: Date): { start: Date, end: Date } {
  // Convert EAT cycle start to UTC for today
  // EAT is UTC+3. So, 15:31 EAT is 12:31 UTC.
  const todayEatStartHour = SUMMARY_CYCLE_START_HOUR_EAT;
  const todayEatStartMinute = SUMMARY_CYCLE_START_MINUTE_EAT;

  // Create a date object for today's EAT start time, then convert to UTC
  // To avoid issues with DST if Deno/system has complex local time, we construct in UTC directly
  const todayCycleStartBoundaryUTC = new Date(Date.UTC(
    nowUtc.getUTCFullYear(),
    nowUtc.getUTCMonth(),
    nowUtc.getUTCDate(),
    todayEatStartHour - 3, // Convert EAT hour to UTC
    todayEatStartMinute
  ));

  let relevantPeriodStartUTC: Date;
  let relevantPeriodEndUTC: Date;

  if (nowUtc.getTime() < todayCycleStartBoundaryUTC.getTime()) {
    // Current UTC time is before today's 12:31 UTC (3:31 PM EAT) boundary.
    // So, summary is for *yesterday's* EAT cycle.
    // Start: Yesterday @ 12:31 UTC (which was Yesterday 3:31 PM EAT)
    relevantPeriodStartUTC = new Date(todayCycleStartBoundaryUTC);
    relevantPeriodStartUTC.setUTCDate(todayCycleStartBoundaryUTC.getUTCDate() - 1);

    // End: Today @ 12:29 UTC (which is Today 3:29 PM EAT)
    relevantPeriodEndUTC = new Date(todayCycleStartBoundaryUTC);
    relevantPeriodEndUTC.setUTCMinutes(todayCycleStartBoundaryUTC.getUTCMinutes() - 2); // Ends 2 mins before the next cycle starts (e.g. 3:29 PM)
  } else {
    // Current UTC time is at or after today's 12:31 UTC (3:31 PM EAT) boundary.
    // So, summary is for *today's* EAT cycle.
    // Start: Today @ 12:31 UTC (Today 3:31 PM EAT)
    relevantPeriodStartUTC = todayCycleStartBoundaryUTC;

    // End: Tomorrow @ 12:29 UTC (Tomorrow 3:29 PM EAT)
    relevantPeriodEndUTC = new Date(todayCycleStartBoundaryUTC);
    relevantPeriodEndUTC.setUTCDate(todayCycleStartBoundaryUTC.getUTCDate() + 1);
    relevantPeriodEndUTC.setUTCMinutes(todayCycleStartBoundaryUTC.getUTCMinutes() - 2);
  }
  return { start: relevantPeriodStartUTC, end: relevantPeriodEndUTC };
}


function formatQuantity(quantity: number): string {
  return quantity.toString().padStart(2, '0');
}

function buildSummaryText(orders: Order[], floorNumber: string, periodStartEAT: Date, periodEndEAT: Date): string {
  let companyName = "N/A Company";
  if (orders.length > 0) {
    const firstOrderCompanyName = orders[0].companies?.name;
    if (firstOrderCompanyName && firstOrderCompanyName.length > 0) {
      if (orders.every(order => order.companies?.name === firstOrderCompanyName)) {
        companyName = firstOrderCompanyName;
      } else {
        companyName = "Multiple Companies";
      }
    } else {
      const distinctCompanyNames = new Set(
        orders.map(o => o.companies?.name).filter(name => name && name.length > 0) // Ensure name is not just empty string
      );
      if (distinctCompanyNames.size > 1) {
        companyName = "Multiple Companies";
      }
    }
  }

  const sb: string[] = [];
  const dateFormatter = (date: Date) => `${date.toLocaleDateString('en-US', { timeZone: 'Africa/Nairobi', month: 'short', day: 'numeric'})} (${date.toLocaleTimeString('en-US', { timeZone: 'Africa/Nairobi', hour: '2-digit', minute: '2-digit', hour12: true })})`;

  sb.push(`Daily Order Summary`);
  sb.push(`Period (EAT): ${dateFormatter(periodStartEAT)} - ${dateFormatter(periodEndEAT)}`);
  sb.push(`------------------------------------`);
  sb.push(`${companyName} - floors ya ${floorNumber}`);
  sb.push('');

  if (orders.length === 0) {
    sb.push("No 'sent' orders for this period.");
    sb.push("Jumla: 00");
    return sb.join('\n');
  }

  const aggregatedItems: { [key: string]: number } = {};
  let totalQuantity = 0;

  for (const order of orders) {
    for (const item of order.order_items) {
      const itemName = item.foods?.name ?? "Unknown Item";
      aggregatedItems[itemName] = (aggregatedItems[itemName] ?? 0) + item.quantity;
      totalQuantity += item.quantity;
    }
  }

  Object.entries(aggregatedItems).forEach(([name, qty]) => {
    sb.push(`- ${name} - ${formatQuantity(qty)}`);
  });

  sb.push(`Jumla: ${formatQuantity(totalQuantity)}`);
  return sb.join('\n');
}

// Helper to send email using Resend
async function sendEmailWithResend(subject: string, textContent: string) {
  if (!RESEND_API_KEY) {
    console.error("RESEND_API_KEY is not set. Email not sent.");
    return { success: false, error: "Resend API key not configured." };
  }
  if (!EMAIL_FROM_ADDRESS.includes('@')) { // Basic check for a valid email format
     console.error("EMAIL_FROM_ADDRESS is not a valid email. Email not sent.");
     return { success: false, error: "Sender email address is not configured correctly." };
  }

  try {
    const response = await fetch('https://api.resend.com/emails', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${RESEND_API_KEY}`,
      },
      body: JSON.stringify({
        from: EMAIL_FROM_ADDRESS,
        to: [TARGET_EMAIL],
        subject: subject,
        text: textContent,
      }),
    });

    if (!response.ok) {
      const errorData = await response.json();
      console.error("Resend API Error:", errorData);
      throw new Error(`Failed to send email via Resend: ${errorData.message || response.statusText}`);
    }

    const data = await response.json();
    console.log("Email sent successfully via Resend:", data.id);
    return { success: true, data };
  } catch (error) {
    console.error("Error sending email with Resend:", error);
    return { success: false, error: error.message };
  }
}


serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  let supabaseClient: SupabaseClient;
  try {
    supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    );

    const nowUtc = new Date(); // Current time in UTC (Deno runtime is UTC)
    const periodUtc = getRelevantSummaryPeriodUTC(nowUtc);
    const periodStartUTC = periodUtc.start;
    const periodEndUTC = periodUtc.end;

    // For display purposes, convert UTC period back to EAT
    const periodStartEAT = new Date(periodStartUTC.getTime() + 3 * 60 * 60 * 1000);
    const periodEndEAT = new Date(periodEndUTC.getTime() + 3 * 60 * 60 * 1000);


    console.log(`[send-daily-order-summary] Triggered at: ${nowUtc.toISOString()} (UTC) / ${new Date(nowUtc.getTime() + 3 * 60 * 60 * 1000).toLocaleString('en-US', {timeZone: 'Africa/Nairobi'})} (EAT)`);
    console.log(`[send-daily-order-summary] Fetching orders for period (UTC): ${periodStartUTC.toISOString()} to ${periodEndUTC.toISOString()}`);
    console.log(`[send-daily-order-summary] Corresponds to period (EAT): ${periodStartEAT.toLocaleString('en-US', {timeZone: 'Africa/Nairobi'})} to ${periodEndEAT.toLocaleString('en-US', {timeZone: 'Africa/Nairobi'})}`);

    const { data: ordersData, error: ordersError } = await supabaseClient
      .from('orders')
      .select(`
        id,
        order_time,
        status,
        companies ( name ),
        order_items (
          id, /* Important to include id for keying if needed */
          quantity,
          foods ( id, name )
        )
      `)
      .eq('status', SUMMARY_ORDER_STATUS)
      .gte('order_time', periodStartUTC.toISOString()) // Query with UTC times
      .lte('order_time', periodEndUTC.toISOString())   // Query with UTC times
      .order('order_time', { ascending: false });

    if (ordersError) {
      console.error('[send-daily-order-summary] Error fetching orders:', ordersError);
      throw ordersError;
    }

    const typedOrders = ordersData as Order[] || [];

    if (typedOrders.length === 0) {
      console.log("[send-daily-order-summary] No 'sent' orders found for the period. No email will be sent.");
      return new Response(JSON.stringify({ message: "No orders to summarize. Email not sent." }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 200, // Success, as the job ran but there was nothing to do
      });
    }

    const summaryText = buildSummaryText(typedOrders, DEFAULT_FLOOR_NUMBER, periodStartEAT, periodEndEAT);
    console.log("[send-daily-order-summary] Generated Summary Text:\n", summaryText);

    // --- Send Email ---
    const emailSubject = `Daily Order Summary - ${periodStartEAT.toLocaleDateString('en-CA', {timeZone: 'Africa/Nairobi'})}`; // YYYY-MM-DD format
    const emailResult = await sendEmailWithResend(emailSubject, summaryText);

    if (!emailResult.success) {
      // Log error, but function still considered "successful" in terms of HTTP response for cron
      // You might want more sophisticated error reporting or retries
      console.error("[send-daily-order-summary] Failed to send email:", emailResult.error);
       return new Response(JSON.stringify({ message: "Summary processed, but email sending failed.", error: emailResult.error, summary: summaryText }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 500, // Indicate email sending failure
      });
    }
    // --- End Send Email ---

    return new Response(JSON.stringify({ message: "Summary processed and email sent.", summary: summaryText }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 200,
    });

  } catch (error) {
    console.error('[send-daily-order-summary] Overall Error in Edge Function:', error.message);
    return new Response(JSON.stringify({ error: error.message }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 500,
    });
  }
});
