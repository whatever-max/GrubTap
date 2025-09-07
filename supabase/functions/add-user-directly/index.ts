// supabase/functions/add-user-directly/index.ts
console.log("ADD-USER-DIRECTLY FUNCTION START - V4.0"); // <-- New Version

import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient, AdminUserAttributes } from "https://esm.sh/@supabase/supabase-js@2";

const SUPER_ADMIN_USER_ID = "ddbf93e1-f6bd-4295-a3a6-6348fe6fdf96"; // YOUR Super Admin User ID

serve(async (req) => {
  console.log(`[add-user-directly V4.0] SERVE HANDLER ENTRY. Method: ${req.method}.`);

  const supabaseAdminClient = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    { auth: { autoRefreshToken: false, persistSession: false } }
  );
  console.log("[add-user-directly V4.0] Admin client initialized.");

  try {
    if (req.method === "OPTIONS") {
      console.log("[add-user-directly V4.0] Handling OPTIONS request.");
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
      console.error("[add-user-directly V4.0] Auth Error: Missing Authorization Header.");
      return new Response(JSON.stringify({ error: "Missing authorization header" }), {
        status: 401, headers: { "Content-Type": "application/json" },
      });
    }
    const token = authHeader.replace("Bearer ", "");

    console.log("[add-user-directly V4.0] Attempting to get user from token...");
    const { data: { user: callingUser }, error: userError } = await supabaseAdminClient.auth.getUser(token);

    if (userError || !callingUser) {
      console.error(`[add-user-directly V4.0] Auth Error: getUser failed. Error: ${userError?.message}, User: ${callingUser}`);
      return new Response(JSON.stringify({ error: userError?.message || "Invalid or expired token." }), {
        status: 401, headers: { "Content-Type": "application/json" },
      });
    }

    console.log(`[add-user-directly V4.0] CALLING USER ID FROM TOKEN: ${callingUser.id}`);
    console.log(`[add-user-directly V4.0] EXPECTED SUPER ADMIN ID: ${SUPER_ADMIN_USER_ID}`);

    if (callingUser.id !== SUPER_ADMIN_USER_ID) {
      console.warn(`[add-user-directly V4.0] AUTHORIZATION FAILED: Calling ID '${callingUser.id}' !== Super Admin ID '${SUPER_ADMIN_USER_ID}'.`);
      return new Response(JSON.stringify({ error: "Unauthorized: Action requires Super Admin privileges." }), {
        status: 403, headers: { "Content-Type": "application/json" },
      });
    }
    console.log("[add-user-directly V4.0] Authorization successful.");

    if (req.method !== 'POST') {
      console.warn(`[add-user-directly V4.0] Method not allowed: ${req.method}. Expected POST.`);
      return new Response(JSON.stringify({ error: 'Method not allowed. Use POST.' }), {
        status: 405, headers: { 'Content-Type': 'application/json' }
      });
    }

    const body = await req.json();
    console.log("[add-user-directly V4.0] Request body parsed:", JSON.stringify(body)); // Log the whole body for debug
    const { email, password, username, firstName, lastName, role, companyName } = body;

    if (!email || !password || !username || !firstName || !lastName || !role) {
      console.error("[add-user-directly V4.0] Validation Error: Missing required user fields.");
      return new Response(JSON.stringify({ error: "Missing required fields (email, password, username, firstName, lastName, role)" }), {
        status: 400, headers: { "Content-Type": "application/json" },
      });
    }
    if (role === 'company' && (!companyName || companyName.trim() === '')) {
      console.error("[add-user-directly V4.0] Validation Error: Company name required for company role.");
      return new Response(JSON.stringify({ error: "Company name is required for company role" }), {
        status: 400, headers: { "Content-Type": "application/json" },
      });
    }
    console.log("[add-user-directly V4.0] Body validation passed.");

    const userAttributes: AdminUserAttributes = {
      email: email,
      password: password, // The temporary password sent from Flutter
      email_confirm: true, // Auto-confirm email
      user_metadata: {
        username: username,
        first_name: firstName,
        last_name: lastName,
        role: role,
        requires_password_change: true, // <-- IMPORTANT for forcing password change
        // initial_company_name: role === 'company' ? companyName?.trim() : undefined, // If needed in auth metadata
      },
    };
    console.log("[add-user-directly V4.0] User attributes for createUser:", JSON.stringify(userAttributes));

    const { data: newUserResponse, error: createError } = await supabaseAdminClient.auth.admin.createUser(userAttributes);

    if (createError) {
      console.error("[add-user-directly V4.0] Supabase Admin Create User Error:", createError.message, JSON.stringify(createError));
      if (createError.message.includes("User already registered") || (createError as any).status === 422) {
        return new Response(JSON.stringify({ error: "User already exists.", details: createError.message }), {
            status: 409, headers: { "Content-Type": "application/json", "Access-Control-Allow-Origin": "*" },
        });
      }
      if (createError.message.toLowerCase().includes("check constraint") && createError.message.toLowerCase().includes("password")) {
         console.error("[add-user-directly V4.0] Password strength/policy error from Supabase. Ensure password meets requirements.");
         return new Response(JSON.stringify({ error: "Password does not meet strength requirements.", details: createError.message }), {
            status: 400, headers: { "Content-Type": "application/json", "Access-Control-Allow-Origin": "*" },
        });
      }
      throw createError;
    }
    if (!newUserResponse || !newUserResponse.user) {
      console.error("[add-user-directly V4.0] Failed to create user or user data missing in auth response.");
      throw new Error("Failed to create user in auth system or user data missing.");
    }

    const newAuthUser = newUserResponse.user;
    console.log(`[add-user-directly V4.0] Auth user created: ${newAuthUser.id} for email ${newAuthUser.email}`);

    // Insert into public.users table (profile)
    const profileData = {
      id: newAuthUser.id,
      email: newAuthUser.email,
      username: username,
      first_name: firstName,
      last_name: lastName,
      role: role,
      // No need to set requires_password_change here, it's in auth.users.user_metadata
    };
    console.log(`[add-user-directly V4.0] Attempting to create profile in public.users with data:`, JSON.stringify(profileData));
    const { error: profileError } = await supabaseAdminClient.from("users").insert(profileData);

    if (profileError) {
      console.error(`[add-user-directly V4.0] Error creating user profile for ${newAuthUser.id}:`, profileError.message, JSON.stringify(profileError));
      await supabaseAdminClient.auth.admin.deleteUser(newAuthUser.id, true); // true to soft delete if possible, otherwise hard
      console.log(`[add-user-directly V4.0] Cleaned up auth user ${newAuthUser.id} due to profile error.`);
      throw new Error(`Failed to create user profile: ${profileError.message}`);
    }
    console.log(`[add-user-directly V4.0] User profile created in public.users: ${newAuthUser.id}`);

    if (role === 'company') {
      const companyData = { name: companyName.trim(), created_by: newAuthUser.id };
      console.log(`[add-user-directly V4.0] Attempting to create company profile with data:`, JSON.stringify(companyData));
      const { error: companyError } = await supabaseAdminClient.from("companies").insert(companyData);

      if (companyError) {
        console.error(`[add-user-directly V4.0] Error creating company profile for ${newAuthUser.id}:`, companyError.message, JSON.stringify(companyError));
        // Rollback: Delete profile and auth user
        await supabaseAdminClient.from("users").delete().eq("id", newAuthUser.id);
        await supabaseAdminClient.auth.admin.deleteUser(newAuthUser.id, true);
        console.log(`[add-user-directly V4.0] Cleaned up profile & auth user ${newAuthUser.id} due to company error.`);
        throw new Error(`Failed to create company profile: ${companyError.message}`);
      }
      console.log(`[add-user-directly V4.0] Company profile created for ${newAuthUser.id}`);
    }

    console.log(`[add-user-directly V4.0] Successfully added user ${email}.`);
    return new Response(JSON.stringify({ message: "User added successfully", userId: newAuthUser.id }), {
      status: 200,
      headers: { "Content-Type": "application/json", "Access-Control-Allow-Origin": "*" },
    });

  } catch (error) {
    console.error("[add-user-directly V4.0] Overall Catch Block Error:", error.message, error.stack);
    const errorMessage = error instanceof Error ? error.message : "An unexpected error occurred.";
    const errorStatus = (error as any).status >= 400 && (error as any).status < 600 ? (error as any).status : 500;
    return new Response(JSON.stringify({ error: errorMessage }), {
      status: errorStatus,
      headers: { "Content-Type": "application/json", "Access-Control-Allow-Origin": "*" },
    });
  }
});
