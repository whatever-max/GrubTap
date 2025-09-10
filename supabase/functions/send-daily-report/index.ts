// functions/send-daily-report/index.ts

import { serve } from "https://deno.land/std@0.192.0/http/server.ts";

console.log("Email function running...");

serve(async (req) => {
  try {
    const { to, subject, message } = await req.json();

    const SENDGRID_API_KEY = Deno.env.get("SENDGRID_API_KEY");
    const SENDGRID_FROM_EMAIL = Deno.env.get("SENDGRID_FROM_EMAIL") ?? "noreply@yourdomain.com";

    const response = await fetch("https://api.sendgrid.com/v3/mail/send", {
      method: "POST",
      headers: {
        Authorization: `Bearer ${SENDGRID_API_KEY}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        personalizations: [{ to: [{ email: to }] }],
        from: { email: SENDGRID_FROM_EMAIL },
        subject,
        content: [{ type: "text/plain", value: message }],
      }),
    });

    if (!response.ok) {
      const error = await response.text();
      console.error("SendGrid error:", error);
      return new Response("Email failed", { status: 500 });
    }

    return new Response("Email sent successfully", { status: 200 });
  } catch (error) {
    console.error("Function error:", error);
    return new Response("Server error", { status: 500 });
  }
});
