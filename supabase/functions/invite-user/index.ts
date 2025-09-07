// supabase/functions/invite-user/index.ts
console.log("INVITE-USER FUNCTION START - V4.0"); // <-- New Version for tracking

import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient, UserAttributes } from "https://esm.sh/@supabase/supabase-js@2";

const SUPER_ADMIN_USER_ID = "ddbf93e1-f6bd-4295-a3a6-6348fe6fdf96"; // YOUR Super Admin User ID

serve(async (req) => {
  console.log(`[invite-user V4.0] SERVE HANDLER ENTRY. Method: ${req.method}.`);

  const supabaseAdminClient = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    { auth: { autoRefreshToken: false, persistSession: false } }
  );
  console.log("[invite-user V4.0] Admin client initialized.");

  try {
    if (req.method === "OPTIONS") {
      console.log("[invite-user V4.0] Handling OPTIONS request.");
      return new Response("ok", {
        headers: {
          "Access-Control-Allow-Origin": "*",
          "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
          "Access-Control-Allow-Methods": "POST, OPTIONS",
        },
      });
    }

    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      console.error("[invite-user V4.0] Auth Error: Missing Authorization Header.");
      return new Response(JSON.stringify({ error: "Missing authorization header" }), {
        status: 401, headers: { "Content-Type": "application/json" },
      });
    }
    const token = authHeader.replace("Bearer ", "");

    console.log("[invite-user V4.0] Attempting to get user from token...");
    const { data: { user: callingUser }, error: userError } = await supabaseAdminClient.auth.getUser(token);

    if (userError || !callingUser) {
      console.error(`[invite-user V4.0] Auth Error: getUser failed. Error: ${userError?.message}, User: ${callingUser}`);
      return new Response(JSON.stringify({ error: userError?.message || "Invalid or expired token." }), {
        status: 401, headers: { "Content-Type": "application/json" },
      });
    }

    console.log(`[invite-user V4.0] CALLING USER ID FROM TOKEN: ${callingUser.id}`);
    console.log(`[invite-user V4.0] EXPECTED SUPER ADMIN ID: ${SUPER_ADMIN_USER_ID}`);

    if (callingUser.id !== SUPER_ADMIN_USER_ID) {
      console.warn(`[invite-user V4.0] AUTHORIZATION FAILED: Calling ID '${callingUser.id}' !== Super Admin ID '${SUPER_ADMIN_USER_ID}'.`);
      return new Response(JSON.stringify({ error: "Unauthorized: Action requires Super Admin privileges." }), {
        status: 403, headers: { "Content-Type": "application/json" },
      });
    }
    console.log("[invite-user V4.0] Authorization successful.");

    if (req.method !== 'POST') { /* ... (same as before) ... */ }

    const { email, role, username, firstName, lastName, companyName } = await req.json();
    console.log(`[invite-user V4.0] Parsed body for email: ${email}, role: ${role}`);

    if (!email || !role) { /* ... (same as before) ... */ }
    if (role === 'company' && (!companyName || companyName.trim() === '')) { /* ... (same as before) ... */ }

    const userMetadata: { [key: string]: any } = {
      role: role,
      invited_by: callingUser.id,
      // You can add more initial data here if needed for the invite email or signup process
      // These become available in the `data` object during user signup if they use the invite link.
      initial_username: username?.trim(),
      initial_first_name: firstName?.trim(),
      initial_last_name: lastName?.trim(),
    };
    if (role === 'company' && companyName && companyName.trim() !== '') {
      userMetadata.initial_company_name = companyName.trim();
    }
    console.log("[invite-user V4.0] User metadata for invite:", JSON.stringify(userMetadata));

    // The redirectTo for invites should point to a page where users can complete signup,
    // which might be your standard signup flow or a specific invite completion page.
    // For password reset, it's specific. For invites, it's broader.
    // Often, you might not need a specific `redirectTo` for invites if the default Supabase flow is okay,
    // or if your app handles any user landing on a signup/login page correctly.
    // If you do use redirectTo, ensure it's in your Supabase "URL Configuration -> Redirect URLs".
    // Example: const inviteRedirectTo = 'myapp://complete-invite-signup';

    console.log(`[invite-user V4.0] Attempting to invite user: ${email}`);
    const { data: inviteResponse, error: inviteError } = await supabaseAdminClient.auth.admin.inviteUserByEmail(
      email,
      { data: userMetadata /*, redirectTo: inviteRedirectTo (optional) */ }
    );

    if (inviteError) {
      console.error("[invite-user V4.0] Supabase Invite Error:", inviteError.message, JSON.stringify(inviteError));
      if (inviteError.message.includes("User already registered") || (inviteError as any).status === 422) { /* ... */ }
      throw inviteError;
    }

    console.log(`[invite-user V4.0] Invite successfully initiated for ${email}. Response: ${JSON.stringify(inviteResponse)}`);
    return new Response(JSON.stringify({ message: `Invitation successfully sent to ${email}.` }), {
      status: 200, headers: { "Content-Type": "application/json", "Access-Control-Allow-Origin": "*" },
    });

  } catch (error) {
    console.error("[invite-user V4.0] Overall Catch Block Error:", error.message, error.stack);
    const errorMessage = error instanceof Error ? error.message : "An unexpected error occurred.";
    const errorStatus = (error as any).status >= 400 && (error as any).status < 600 ? (error as any).status : 500;
    return new Response(JSON.stringify({ error: errorMessage }), {
      status: errorStatus, headers: { "Content-Type": "application/json", "Access-Control-Allow-Origin": "*" },
    });
  }
});
