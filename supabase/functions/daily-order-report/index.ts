// supabase/functions/daily-order-report/index.ts
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js";
serve(async ()=>{
  const supabase = createClient(Deno.env.get("SUPABASE_URL"), Deno.env.get("SUPABASE_SERVICE_ROLE_KEY"));
  // East Africa Time (UTC+3)
  const now = new Date();
  now.setUTCHours(now.getUTCHours() + 3);
  const start = new Date(now);
  start.setDate(start.getDate() - 1);
  start.setHours(15, 31, 0, 0);
  const end = new Date(now);
  end.setHours(10, 33, 0, 0);
  const { data: orders, error } = await supabase.from("orders").select(`
      id,
      company:companies(name),
      order_items:order_items(
        quantity,
        food:foods(name)
      )
    `).eq("status", "sent").gte("order_time", start.toISOString()).lte("order_time", end.toISOString());
  if (error) {
    console.error("Order fetch error:", error);
    return new Response("Failed to fetch orders", {
      status: 500
    });
  }
  if (!orders || orders.length === 0) {
    return new Response("No orders found", {
      status: 200
    });
  }
  // Group orders per company
  const companyOrders = {};
  for (const order of orders){
    const company = order.company?.name ?? "Unknown Company";
    if (!companyOrders[company]) companyOrders[company] = {};
    for (const item of order.order_items || []){
      const foodName = item.food?.name ?? "Unknown Food";
      companyOrders[company][foodName] = (companyOrders[company][foodName] || 0) + item.quantity;
    }
  }
  // Build the email text
  let emailBody = "";
  for (const [company, foods] of Object.entries(companyOrders)){
    emailBody += `${company}\n`;
    let total = 0;
    for (const [food, qty] of Object.entries(foods)){
      emailBody += `${food} ${qty}\n`;
      total += qty;
    }
    emailBody += `jumla ${total}\n\n`;
  }
  // Send email using Resend email function
  const { error: emailError } = await supabase.functions.invoke("send-email", {
    body: {
      to: [
        "eugengodbless85@gmail.com",
        "grubtap25@gmail.com",
        "godbssam@gmail.com",
        "codex6992@gmail.com"
      ],
      subject: `Order Report: ${start.toISOString().slice(0, 10)} → ${end.toISOString().slice(0, 10)}`,
      text: emailBody.trim()
    }
  });
  if (emailError) {
    console.error("Email failed:", emailError);
    return new Response("Email failed", {
      status: 500
    });
  }
  return new Response("Email sent", {
    status: 200
  });
});
