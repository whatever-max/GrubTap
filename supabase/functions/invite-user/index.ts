// supabase/functions/invite-user/index.ts
console.log("INVITE-USER FUNCTION START - V3.0"); // <--- GLOBAL SCOPE LOG

import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const SUPER_ADMIN_USER_ID = "ddbf93e1-f6bd-4295-a3a6-6348fe6fdf96"; // From your logs

serve(async (req) => {
  console.log(`[invite-user V3.0] SERVE HANDLER ENTRY. Method: ${req.method}. URL: ${req.url}`);

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

  if (!supabaseUrl || !serviceRoleKey) {
    console.error("[invite-user V3.0] CRITICAL: SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY is missing from environment variables.");
    return new Response(JSON.stringify({ error: "Server configuration error." }), {
      status: 500, headers: { "Content-Type": "application/json" },
    });
  }
  // console.log(`[invite-user V3.0] Env vars: URL=${supabaseUrl ? 'OK' : 'MISSING'}, Key=${serviceRoleKey ? 'OK' : 'MISSING'}`);


  const supabaseAdminClient = createClient(supabaseUrl, serviceRoleKey, {
    auth: { persistSession: false },
  });
  console.log("[invite-user V3.0] Admin client initialized.");

  try {
    if (req.method === "OPTIONS") {
      console.log("[invite-user V3.0] Handling OPTIONS request.");
      return new Response("ok", {
        headers: {
          "Access-Control-Allow-Origin": "*",
          "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
          "Access-Control-Allow-Methods": "POST, OPTIONS",
        },
      });
    }
    console.log("[invite-user V3.0] Not an OPTIONS request, proceeding.");


    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      console.error("[invite-user V3.0] Missing Authorization Header.");
      return new Response(JSON.stringify({ error: "Missing authorization header" }), {
        status: 401, headers: { "Content-Type": "application/json" },
      });
    }
    const token = authHeader.replace("Bearer ", "");
    console.log("[invite-user V3.0] Token extracted from header.");


    console.log("[invite-user V3.0] Attempting to get user from token...");
    const { data: { user: callingUser }, error: userError } = await supabaseAdminClient.auth.getUser(token);

    if (userError) {
      console.error("[invite-user V3.0] Error getting user from token:", userError.message, JSON.stringify(userError));
      return new Response(JSON.stringify({ error: `Auth Error: ${userError.message}` }), {
        status: 401, headers: { "Content-Type": "application/json" },
      });
    }
    if (!callingUser) {
      console.error("[invite-user V3.0] No user returned from token (callingUser is null). This likely means the token is invalid or expired.");
      return new Response(JSON.stringify({ error: "Invalid or expired token (no user found)." }), {
        status: 401, headers: { "Content-Type": "application/json" },
      });
    }

    console.log(`[invite-user V3.0] CALLING USER ID FROM TOKEN: ${callingUser.id}`);
    console.log(`[invite-user V3.0] EXPECTED SUPER ADMIN ID: ${SUPER_ADMIN_USER_ID}`);

    if (callingUser.id !== SUPER_ADMIN_USER_ID) {
      console.warn(`[invite-user V3.0] AUTHORIZATION FAILED: Calling user ID '${callingUser.id}' does not match SUPER_ADMIN_USER_ID '${SUPER_ADMIN_USER_ID}'.`);
      return new Response(JSON.stringify({ error: "Unauthorized: Action requires Super Admin privileges." }), {
        status: 403, headers: { "Content-Type": "application/json" },
      });
    }
    console.log("[invite-user V3.0] Authorization successful. User is Super Admin.");


    if (req.method !== 'POST') {
      console.log(`[invite-user V3.0] Method not allowed: ${req.method}. Expected POST.`);
      return new Response(JSON.stringify({ error: 'Method not allowed. Use POST.' }), {
        status: 405, headers: { 'Content-Type': 'application/json' },
      });
    }
    console.log("[invite-user V3.0] Request method is POST. Attempting to parse JSON body.");

    const body = await req.json();
    const { email, role, username, firstName, lastName, companyName } = body;
    console.log(`[invite-user V3.0] Parsed body: email=${email}, role=${role}, username=${username}, firstName=${firstName}, lastName=${lastName}, companyName=${companyName}`);


    if (!email || !role) {
      console.error("[invite-user V3.0] Validation Error: Email and role are required.");
      return new Response(JSON.stringify({ error: "Email and role are required." }), {
        status: 400, headers: { "Content-Type": "application/json" },
      });
    }
    if (role === 'company' && (!companyName || companyName.trim() === '')) {
      console.error("[invite-user V3.0] Validation Error: Company name is required for company role.");
      return new Response(JSON.stringify({ error: "Company name is required for company role" }), {
        status: 400, headers: { "Content-Type": "application/json" },
      });
    }
    console.log("[invite-user V3.0] Body validation passed.");

    const userMetadata: { [key: string]: any } = {
      role: role,
      invited_by: callingUser.id,
      initial_username: username,
      initial_first_name: firstName,
      initial_last_name: lastName,
    };
    if (role === 'company' && companyName && companyName.trim() !== '') {
      userMetadata.initial_company_name = companyName.trim();
    }
    console.log("[invite-user V3.0] User metadata prepared:", JSON.stringify(userMetadata));

    console.log(`[invite-user V3.0] Attempting to call supabaseAdminClient.auth.admin.inviteUserByEmail for ${email}`);
    const { data: inviteData, error: inviteError } = await supabaseAdminClient.auth.admin.inviteUserByEmail(
      email,
      { data: userMetadata }
    );

    if (inviteError) {
      console.error("[invite-user V3.0] Supabase Invite Error (from inviteUserByEmail call):", inviteError.message, JSON.stringify(inviteError));
      if (inviteError.message.includes("User already registered") || (inviteError as any).status === 422) {
        return new Response(JSON.stringify({ error: "User already exists or has a pending invite.", details: inviteError.message }), {
          status: 409, headers: { "Content-Type": "application/json", "Access-Control-Allow-Origin": "*" },
        });
      }
      // Check if the service_role client itself was denied
      if (inviteError.message.toLowerCase().includes("user is not allowed") || inviteError.message.toLowerCase().includes("permission denied")) {
         console.error("[invite-user V3.0] CRITICAL PERMISSION ISSUE: The service_role client itself was denied the inviteUserByEmail action. This is a Supabase permissions issue, not the SUPER_ADMIN_USER_ID check. Check your service_role key capabilities.");
      }
      throw inviteError; // Rethrow for generic catch if not handled
    }

    // Supabase often returns a minimal response on success for invites, 'inviteData.user' might be present or not.
    if (!inviteData || !inviteData.user) {
      console.warn(`[invite-user V3.0] Invite call for ${email} seems successful, but inviteData.user is missing in response. This is often normal.`);
    } else {
      console.log(`[invite-user V3.0] Invitation successfully initiated for ${inviteData.user.email}, Invited User ID (potential): ${inviteData.user.id}`);
    }

    console.log(`[invite-user V3.0] Successfully processed invite for ${email}.`);
    return new Response(JSON.stringify({ message: `Invitation successfully sent to ${email}.` }), {
      status: 200,
      headers: { "Content-Type": "application/json", "Access-Control-Allow-Origin": "*" },
    });

  } catch (error) {
    // This catches errors from req.json() if body is not valid JSON, or rethrown errors
    console.error("[invite-user V3.0] Overall Catch Block Error:", error.message, error.stack, JSON.stringify(error));
    const errorMessage = error instanceof Error ? error.message : "An unexpected error occurred in the function.";
    const errorStatus = (error as any).status >= 400 && (error as any).status < 600 ? (error as any).status : 500;
    return new Response(JSON.stringify({ error: errorMessage }), {
      status: errorStatus,
      headers: { "Content-Type": "application/json", "Access-Control-Allow-Origin": "*" },
    });
  }
});

