import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { Resend } from "npm:resend";

const resend = new Resend(Deno.env.get("RESEND_API_KEY"));

serve(async (req) => {
  try {
    const { to, subject, text } = await req.json();

    if (!to || !subject || !text) {
      return new Response("Missing required fields", { status: 400 });
    }

    const { error } = await resend.emails.send({
      from: "onboarding@resend.dev", // Free sender
      to,
      subject,
      text
    });

    if (error) {
      console.error("Resend error:", error);
      return new Response("Failed to send email", { status: 500 });
    }

    return new Response("Email sent", { status: 200 });

  } catch (err) {
    console.error("Unexpected error:", err);
    return new Response("Server error", { status: 500 });
  }
});
