// supabase/functions/exchange-reset-code/index.ts
console.log("EXCHANGE-RESET-CODE FUNCTION START - V1.1"); // Log version

import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

serve(async (req) => {
  console.log(`[exchange-reset-code V1.1] SERVE HANDLER ENTRY. Method: ${req.method}.`);

  // Use ANON KEY for client-like operations like verifyOtp
  const supabaseClient = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_ANON_KEY")!
  );
  console.log("[exchange-reset-code V1.1] Supabase client (anon key) initialized.");

  try {
    if (req.method === "OPTIONS") {
      console.log("[exchange-reset-code V1.1] Handling OPTIONS request.");
      return new Response("ok", {
        headers: {
          "Access-Control-Allow-Origin": "*", // Be more specific in production if possible
          "Access-Control-Allow-Headers": "apikey, content-type, x-client-info",
          "Access-Control-Allow-Methods": "POST, OPTIONS",
        },
      });
    }

    if (req.method !== 'POST') {
      console.warn(`[exchange-reset-code V1.1] Invalid method: ${req.method}.`);
      return new Response(JSON.stringify({ error: "Method not allowed. Only POST requests are accepted." }), {
        status: 405, headers: { "Content-Type": "application/json" },
      });
    }

    const { code, email } = await req.json();
    console.log(`[exchange-reset-code V1.1] Parsed body - Code: ${code}, Email: ${email}`);

    if (!code || !email) {
      console.error("[exchange-reset-code V1.1] Validation Error: Code and Email are required.");
      return new Response(JSON.stringify({ error: "Reset code and email are required." }), {
        status: 400, headers: { "Content-Type": "application/json" },
      });
    }

    console.log(`[exchange-reset-code V1.1] Attempting to verify OTP for recovery. Email: ${email}, Token (Code): ${code}`);
    const { data: sessionData, error: verifyError } = await supabaseClient.auth.verifyOtp({
      type: 'recovery',
      email: email,
      token: code,
    });

    if (verifyError) {
      console.error("[exchange-reset-code V1.1] Supabase verifyOtp (recovery) Error:", verifyError.message, JSON.stringify(verifyError));
      return new Response(JSON.stringify({
        error: `Invalid or expired password reset link/code. Server: ${verifyError.message}`
      }), {
        status: verifyError.status || 400,
        headers: { "Content-Type": "application/json" },
      });
    }

    if (sessionData && sessionData.session && sessionData.user) {
      console.log(`[exchange-reset-code V1.1] OTP Verification successful. Session established for user: ${sessionData.user.id}`);
      return new Response(JSON.stringify({
        message: "Reset code verified. Session established.",
        accessToken: sessionData.session.access_token,
        refreshToken: sessionData.session.refresh_token,
        expiresAt: sessionData.session.expires_at,
        user: sessionData.user,
      }), {
        status: 200,
        headers: { "Content-Type": "application/json", "Access-Control-Allow-Origin": "*" },
      });
    } else {
      console.error("[exchange-reset-code V1.1] OTP Verification response incomplete.", JSON.stringify(sessionData));
      return new Response(JSON.stringify({ error: "Failed to establish session after code verification (incomplete data). Please try again." }), {
        status: 500, headers: { "Content-Type": "application/json" },
      });
    }

  } catch (error) {
    console.error("[exchange-reset-code V1.1] Overall Catch Block Error:", error.message, error.stack);
    const errorMessage = error instanceof Error ? error.message : "An unexpected error occurred.";
    const errorStatus = (error as any).status >= 400 && (error as any).status < 600 ? (error as any).status : 500;
    return new Response(JSON.stringify({ error: errorMessage }), {
      status: errorStatus, headers: { "Content-Type": "application/json", "Access-Control-Allow-Origin": "*" },
    });
  }
});
