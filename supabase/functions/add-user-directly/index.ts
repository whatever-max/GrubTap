// supabase/functions/add-user-directly/index.ts
console.log("ADD-USER-DIRECTLY FUNCTION START - V3.0"); // <--- GLOBAL SCOPE LOG

import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient, AdminUserAttributes } from "https://esm.sh/@supabase/supabase-js@2";

const SUPER_ADMIN_USER_ID = "ddbf93e1-f6bd-4295-a3a6-6348fe6fdf96"; // Your Super Admin's UUID

serve(async (req) => {
  console.log(`[add-user-directly V3.0] SERVE HANDLER ENTRY. Method: ${req.method}. URL: ${req.url}`);

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

  if (!supabaseUrl || !serviceRoleKey) {
    console.error("[add-user-directly V3.0] CRITICAL: SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY is missing from environment variables.");
    return new Response(JSON.stringify({ error: "Server configuration error." }), {
      status: 500, headers: { "Content-Type": "application/json" },
    });
  }
  // console.log(`[add-user-directly V3.0] Env vars: URL=${supabaseUrl ? 'OK' : 'MISSING'}, Key=${serviceRoleKey ? 'OK' : 'MISSING'}`);

  const supabaseAdminClient = createClient(supabaseUrl, serviceRoleKey, {
    auth: { persistSession: false },
  });
  console.log("[add-user-directly V3.0] Admin client initialized.");

  try {
    if (req.method === "OPTIONS") {
      console.log("[add-user-directly V3.0] Handling OPTIONS request.");
      return new Response("ok", {
        headers: {
          "Access-Control-Allow-Origin": "*",
          "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
          "Access-Control-Allow-Methods": "POST, OPTIONS",
        },
      });
    }
    console.log("[add-user-directly V3.0] Not an OPTIONS request, proceeding.");

    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      console.error("[add-user-directly V3.0] Missing Authorization Header.");
      return new Response(JSON.stringify({ error: "Missing authorization header" }), {
        status: 401, headers: { "Content-Type": "application/json" },
      });
    }
    const token = authHeader.replace("Bearer ", "");
    console.log("[add-user-directly V3.0] Token extracted from header.");

    console.log("[add-user-directly V3.0] Attempting to get user from token...");
    const { data: { user: callingUser }, error: userError } = await supabaseAdminClient.auth.getUser(token);

    if (userError) {
      console.error("[add-user-directly V3.0] Error getting user from token:", userError.message, JSON.stringify(userError));
      return new Response(JSON.stringify({ error: `Auth Error: ${userError.message}` }), {
        status: 401, headers: { "Content-Type": "application/json" },
      });
    }
    if (!callingUser) {
      console.error("[add-user-directly V3.0] No user returned from token (callingUser is null). This likely means the token is invalid or expired.");
      return new Response(JSON.stringify({ error: "Invalid or expired token (no user found)." }), {
        status: 401, headers: { "Content-Type": "application/json" },
      });
    }

    console.log(`[add-user-directly V3.0] CALLING USER ID FROM TOKEN: ${callingUser.id}`);
    console.log(`[add-user-directly V3.0] EXPECTED SUPER ADMIN ID: ${SUPER_ADMIN_USER_ID}`);

    if (callingUser.id !== SUPER_ADMIN_USER_ID) {
      console.warn(`[add-user-directly V3.0] AUTHORIZATION FAILED: Calling user ID '${callingUser.id}' does not match SUPER_ADMIN_USER_ID '${SUPER_ADMIN_USER_ID}'.`);
      return new Response(JSON.stringify({ error: "Unauthorized: Action requires Super Admin privileges." }), {
        status: 403, headers: { "Content-Type": "application/json" },
      });
    }
    console.log("[add-user-directly V3.0] Authorization successful. User is Super Admin.");

    if (req.method !== 'POST') {
      console.log(`[add-user-directly V3.0] Method not allowed: ${req.method}. Expected POST.`);
      return new Response(JSON.stringify({ error: 'Method not allowed. Use POST.' }), {
        status: 405, headers: { 'Content-Type': 'application/json' },
      });
    }
    console.log("[add-user-directly V3.0] Request method is POST. Attempting to parse JSON body.");

    const body = await req.json();
    const { email, password, username, firstName, lastName, role, companyName } = body;
    console.log(`[add-user-directly V3.0] Parsed body: email=${email}, role=${role}, username=${username}, firstName=${firstName}, lastName=${lastName}, companyName=${companyName}`);


    if (!email || !password || !username || !firstName || !lastName || !role) {
      console.error("[add-user-directly V3.0] Validation Error: Missing required user fields.");
      return new Response(JSON.stringify({ error: "Missing required user fields (email, password, username, firstName, lastName, role are required)" }), {
        status: 400, headers: { "Content-Type": "application/json" },
      });
    }
    if (role === 'company' && (!companyName || companyName.trim() === '')) {
      console.error("[add-user-directly V3.0] Validation Error: Company name is required for company role.");
      return new Response(JSON.stringify({ error: "Company name is required for company role" }), {
        status: 400, headers: { "Content-Type": "application/json" },
      });
    }
    console.log("[add-user-directly V3.0] Body validation passed.");

    const userAttributes: AdminUserAttributes = {
      email: email,
      password: password,
      email_confirm: true, // Auto-confirm email for admin-created users
      user_metadata: {
        username: username,
        first_name: firstName,
        last_name: lastName,
        role: role,
        // initial_company_name: role === 'company' ? companyName?.trim() : undefined, // If you want to store this in auth.users.user_metadata
      },
    };
    console.log("[add-user-directly V3.0] User attributes prepared:", JSON.stringify(userAttributes));

    console.log(`[add-user-directly V3.0] Attempting to create auth user: ${email}`);
    const { data: newUserResponse, error: createError } = await supabaseAdminClient.auth.admin.createUser(userAttributes);

    if (createError) {
      console.error("[add-user-directly V3.0] Supabase Admin Create User Error:", createError.message, JSON.stringify(createError));
      if (createError.message.includes("User already registered") || (createError as any).status === 422) {
        return new Response(JSON.stringify({ error: "User already exists.", details: createError.message }), {
          status: 409, headers: { "Content-Type": "application/json", "Access-Control-Allow-Origin": "*" },
        });
      }
      // Check if the service_role client itself was denied
      if (createError.message.toLowerCase().includes("user is not allowed") || createError.message.toLowerCase().includes("permission denied")) {
         console.error("[add-user-directly V3.0] CRITICAL PERMISSION ISSUE: The service_role client itself was denied the createUser action. This is a Supabase permissions issue, not the SUPER_ADMIN_USER_ID check. Check your service_role key capabilities.");
      }
      throw createError; // Rethrow for generic catch if not handled
    }
    if (!newUserResponse || !newUserResponse.user) {
      console.error("[add-user-directly V3.0] Failed to create user or user data missing in auth response.");
      throw new Error("Failed to create user in auth system or user data missing.");
    }

    const newAuthUser = newUserResponse.user;
    console.log(`[add-user-directly V3.0] Auth user created: ${newAuthUser.id} for email ${newAuthUser.email}`);

    // Insert into public.users table (profile)
    console.log(`[add-user-directly V3.0] Attempting to create profile in public.users for: ${newAuthUser.id}`);
    const { error: profileError } = await supabaseAdminClient.from("users").insert({
      id: newAuthUser.id,
      email: newAuthUser.email,
      username: username,
      first_name: firstName,
      last_name: lastName,
      role: role,
    }).select(); // .select() is good practice here

    if (profileError) {
      console.error(`[add-user-directly V3.0] Error creating user profile in public.users for ${newAuthUser.id}:`, profileError.message, JSON.stringify(profileError));
      console.log(`[add-user-directly V3.0] Attempting to delete auth user ${newAuthUser.id} due to profile error.`);
      await supabaseAdminClient.auth.admin.deleteUser(newAuthUser.id);
      console.log(`[add-user-directly V3.0] Cleaned up auth user ${newAuthUser.id}.`);
      throw new Error(`Failed to create user profile: ${profileError.message}`);
    }
    console.log(`[add-user-directly V3.0] User profile created in public.users: ${newAuthUser.id}`);

    if (role === 'company' && companyName && companyName.trim() !== '') {
      console.log(`[add-user-directly V3.0] Attempting to create company for: ${newAuthUser.id} with name: ${companyName.trim()}`);
      const { error: companyError } = await supabaseAdminClient.from("companies").insert({
        name: companyName.trim(),
        created_by: newAuthUser.id,
      }).select(); // .select() is good practice

      if (companyError) {
        console.error(`[add-user-directly V3.0] Error creating company profile for ${newAuthUser.id}:`, companyError.message, JSON.stringify(companyError));
        console.log(`[add-user-directly V3.0] Attempting to delete profile and auth user ${newAuthUser.id} due to company error.`);
        await supabaseAdminClient.from("users").delete().eq("id", newAuthUser.id);
        await supabaseAdminClient.auth.admin.deleteUser(newAuthUser.id);
        console.log(`[add-user-directly V3.0] Cleaned up user profile and auth user ${newAuthUser.id}.`);
        throw new Error(`Failed to create company profile: ${companyError.message}`);
      }
      console.log(`[add-user-directly V3.0] Company profile created for ${newAuthUser.id}`);
    }

    console.log(`[add-user-directly V3.0] Successfully added user ${email}.`);
    return new Response(JSON.stringify({ message: "User added successfully", userId: newAuthUser.id }), {
      status: 200,
      headers: { "Content-Type": "application/json", "Access-Control-Allow-Origin": "*" },
    });

  } catch (error) {
    console.error("[add-user-directly V3.0] Overall Catch Block Error:", error.message, error.stack, JSON.stringify(error));
    const errorMessage = error instanceof Error ? error.message : "An unexpected error occurred in the function.";
    const errorStatus = (error as any).status >= 400 && (error as any).status < 600 ? (error as any).status : 500; // Use a broader range for error statuses
    return new Response(JSON.stringify({ error: errorMessage }), {
      status: errorStatus,
      headers: { "Content-Type": "application/json", "Access-Control-Allow-Origin": "*" },
    });
  }
});
