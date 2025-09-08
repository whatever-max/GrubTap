// supabase/functions/invite-user/index.ts
console.log("INVITE-USER FUNCTION START - V4.1"); // <-- New Version for tracking this change

import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient, UserAttributes } from "https://esm.sh/@supabase/supabase-js@2";

// Ensure this User ID is correct for the Super Admin who is allowed to invite
const SUPER_ADMIN_USER_ID = "ddbf93e1-f6bd-4295-a3a6-6348fe6fdf96";

serve(async (req) => {
  console.log(`[invite-user V4.1] SERVE HANDLER ENTRY. Method: ${req.method}.`);

  // Ensure environment variables are set in your Supabase project settings for this function
  const supabaseAdminClient = createClient(Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    { auth: { autoRefreshToken: false, persistSession: false } }
  );
  console.log("[invite-user V4.1] Admin client initialized.");

  try {
    // Standard pre-flight request handling for CORS
    if (req.method === "OPTIONS") {
      console.log("[invite-user V4.1] Handling OPTIONS request.");
      return new Response("ok", {
        headers: {
          "Access-Control-Allow-Origin": "*", // Or your specific app domain for better security
          "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
          "Access-Control-Allow-Methods": "POST, OPTIONS", // Ensure POST is allowed
        },
      });
    }

    // Authorization: Check if the calling user is the designated Super Admin
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      console.error("[invite-user V4.1] Auth Error: Missing Authorization Header.");
      return new Response(JSON.stringify({ error: "Missing authorization header" }), {
        status: 401, headers: { "Content-Type": "application/json" },
      });
    }
    const token = authHeader.replace("Bearer ", "");

    console.log("[invite-user V4.1] Attempting to get user from token...");
    const { data: { user: callingUser }, error: userError } = await supabaseAdminClient.auth.getUser(token);

    if (userError || !callingUser) {
      console.error(`[invite-user V4.1] Auth Error: getUser failed. Error: ${userError?.message}, User: ${callingUser}`);
      return new Response(JSON.stringify({ error: userError?.message || "Invalid or expired token." }), {
        status: 401, headers: { "Content-Type": "application/json" },
      });
    }

    console.log(`[invite-user V4.1] CALLING USER ID FROM TOKEN: ${callingUser.id}`);
    console.log(`[invite-user V4.1] EXPECTED SUPER ADMIN ID: ${SUPER_ADMIN_USER_ID}`);

    if (callingUser.id !== SUPER_ADMIN_USER_ID) {
      console.warn(`[invite-user V4.1] AUTHORIZATION FAILED: Calling ID '${callingUser.id}' !== Super Admin ID '${SUPER_ADMIN_USER_ID}'.`);
      return new Response(JSON.stringify({ error: "Unauthorized: Action requires Super Admin privileges." }), {
        status: 403, headers: { "Content-Type": "application/json" },
      });
    }
    console.log("[invite-user V4.1] Authorization successful for Super Admin.");

    // Ensure it's a POST request
    if (req.method !== 'POST') {
      console.warn(`[invite-user V4.1] Invalid method: ${req.method}. Only POST is allowed.`);
      return new Response(JSON.stringify({ error: "Method not allowed. Only POST requests are accepted." }), {
        status: 405, headers: { "Content-Type": "application/json" },
      });
    }

    // Parse the request body from your Flutter app
    const { email, role, username, firstName, lastName, companyName } = await req.json();
    console.log(`[invite-user V4.1] Parsed body - Email: ${email}, Role: ${role}, Username: ${username}, Company: ${companyName}`);

    // Validate required fields
    if (!email || !role) {
      console.error("[invite-user V4.1] Validation Error: Email and Role are required.");
      return new Response(JSON.stringify({ error: "Email and Role are required." }), {
        status: 400, headers: { "Content-Type": "application/json" },
      });
    }
    if (role === 'company' && (!companyName || companyName.trim() === '')) {
      console.error("[invite-user V4.1] Validation Error: Company Name is required for company role.");
      return new Response(JSON.stringify({ error: "Company Name is required for 'company' role." }), {
        status: 400, headers: { "Content-Type": "application/json" },
      });
    }

    // Prepare user metadata to be stored with the user upon signup from invite
    const userMetadata: { [key: string]: any } = {
      role: role,
      invited_by: callingUser.id,
      initial_username: username?.trim() || null, // Ensure empty strings become null if desired
      initial_first_name: firstName?.trim() || null,
      initial_last_name: lastName?.trim() || null,
    };
    if (role === 'company' && companyName && companyName.trim() !== '') {
      userMetadata.initial_company_name = companyName.trim();
    }
    // Remove any keys with null values if you prefer cleaner metadata
    Object.keys(userMetadata).forEach(key => userMetadata[key] === null && delete userMetadata[key]);
    console.log("[invite-user V4.1] User metadata for invite:", JSON.stringify(userMetadata));

    // ***** THIS IS THE CRITICAL UPDATE *****
    const inviteRedirectTo = 'myapp://invite'; // Your specific deep link for invite acceptance
    console.log(`[invite-user V4.1] Using redirectTo: '${inviteRedirectTo}'`);
    // **************************************

    console.log(`[invite-user V4.1] Attempting to invite user: ${email} with metadata and redirect.`);
    const { data: inviteResponse, error: inviteError } = await supabaseAdminClient.auth.admin.inviteUserByEmail(
      email,
      {
        data: userMetadata,
        redirectTo: inviteRedirectTo // Ensure this is correctly passed
      }
    );

    if (inviteError) {
      console.error("[invite-user V4.1] Supabase Invite Error:", inviteError.message, JSON.stringify(inviteError));
      // Handle specific errors like user already registered more gracefully
      if (inviteError.message.includes("User already registered") || (inviteError as any).status === 422) {
        return new Response(JSON.stringify({ error: "This email is already registered." }), {
          status: 422, headers: { "Content-Type": "application/json" },
        });
      }
      // For other errors, re-throw or return a generic server error
      // throw inviteError; // This would be caught by the outer catch block
      return new Response(JSON.stringify({ error: `Failed to send invitation: ${inviteError.message}` }), {
        status: (inviteError as any).status || 500, headers: { "Content-Type": "application/json" },
      });
    }

    console.log(`[invite-user V4.1] Invite successfully initiated for ${email}. Response User ID: ${inviteResponse.user?.id}`);
    return new Response(JSON.stringify({ message: `Invitation successfully sent to ${email}.`, userId: inviteResponse.user?.id }), {
      status: 200,
      headers: {
        "Content-Type": "application/json",
        "Access-Control-Allow-Origin": "*" // Required if your Flutter app calls this from web, or for CORS in general
      },
    });

  } catch (error) {
    console.error("[invite-user V4.1] Overall Catch Block Error:", error.message, error.stack);
    const errorMessage = error instanceof Error ? error.message : "An unexpected error occurred.";
    // Ensure error status is a valid HTTP status code
    const errorStatus = (error as any).status && typeof (error as any).status === 'number' && (error as any).status >= 400 && (error as any).status < 600
                        ? (error as any).status
                        : 500;
    return new Response(JSON.stringify({ error: errorMessage }), {
      status: errorStatus,
      headers: {
        "Content-Type": "application/json",
        "Access-Control-Allow-Origin": "*"
      },
    });
  }
});
