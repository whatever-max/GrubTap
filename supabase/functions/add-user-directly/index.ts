    // supabase/functions/add-user-directly/index.ts

    import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
    import { createClient, AdminUserAttributes } from "https://esm.sh/@supabase/supabase-js@2";

    const SUPER_ADMIN_USER_ID = "ddbf93e1-f6bd-4295-a3a6-6348fe6fdf96"; // Your Super Admin's UUID

    serve(async (req) => {
      // Create a Supabase client with the Service Role Key
      // These environment variables are automatically available in the Supabase Edge Function environment
      const supabaseAdminClient = createClient(
        Deno.env.get("SUPABASE_URL")!,
        Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
        { auth: { persistSession: false } } // Important for server-side
      );

      try {
        // 1. Handle CORS preflight OPTIONS request (important for web clients)
        if (req.method === "OPTIONS") {
          return new Response("ok", {
            headers: {
              "Access-Control-Allow-Origin": "*", // Or your specific app domain e.g., "https://yourapp.com"
              "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
              "Access-Control-Allow-Methods": "POST, OPTIONS", // Specify allowed methods
            }
          });
        }

        // 2. Get the authorization header from the invoking client
        const authHeader = req.headers.get("Authorization");
        if (!authHeader) {
          console.error("[add-user-directly] Missing Authorization Header");
          return new Response(JSON.stringify({ error: "Missing authorization header" }), {
            status: 401,
            headers: { "Content-Type": "application/json" },
          });
        }
        const token = authHeader.replace("Bearer ", "");

        // 3. Get user from token (this also verifies the token)
        const { data: { user: callingUser }, error: userError } = await supabaseAdminClient.auth.getUser(token);

        if (userError || !callingUser) {
          console.error("[add-user-directly] Auth Error from token:", userError?.message);
          return new Response(JSON.stringify({ error: userError?.message || "Invalid token" }), {
            status: 401,
            headers: { "Content-Type": "application/json" },
          });
        }

        // 4. Check if the authenticated user IS the Super Admin
        if (callingUser.id !== SUPER_ADMIN_USER_ID) {
          console.warn(`[add-user-directly] Unauthorized attempt to add user by: ${callingUser.id}`);
          return new Response(JSON.stringify({ error: "Unauthorized: Not Super Admin" }), {
            status: 403,
            headers: { "Content-Type": "application/json" },
          });
        }

        // 5. If Super Admin, proceed: Parse request body for new user details
        // Ensure the request method is POST
        if (req.method !== 'POST') {
            return new Response(JSON.stringify({ error: 'Method not allowed. Use POST.' }), {
                status: 405, headers: { 'Content-Type': 'application/json' }
            });
        }

        const body = await req.json();
        const { email, password, username, firstName, lastName, role, companyName } = body;

        if (!email || !password || !username || !firstName || !lastName || !role) {
          return new Response(JSON.stringify({ error: "Missing required user fields" }), {
            status: 400,
            headers: { "Content-Type": "application/json" },
          });
        }
        if (role === 'company' && (!companyName || companyName.trim() === '')) {
            return new Response(JSON.stringify({ error: "Company name is required for company role" }), {
                status: 400,
                headers: { "Content-Type": "application/json" },
            });
        }

        const userAttributes: AdminUserAttributes = {
          email: email,
          password: password,
          email_confirm: true, // Auto-confirm email for admin-created users
          user_metadata: {
            username: username,
            first_name: firstName,
            last_name: lastName,
            role: role,
          },
        };

        console.log("[add-user-directly] Attempting to create auth user:", email);
        const { data: newUserResponse, error: createError } = await supabaseAdminClient.auth.admin.createUser(userAttributes);

        if (createError) {
          console.error("[add-user-directly] Supabase Admin Create User Error:", createError.message, JSON.stringify(createError));
          throw createError; // Rethrow to be caught by the outer try-catch
        }
        if (!newUserResponse || !newUserResponse.user) {
            console.error("[add-user-directly] Failed to create user or user data missing in response");
            throw new Error("Failed to create user in auth system or user data missing.");
        }

        const newAuthUser = newUserResponse.user;
        console.log(`[add-user-directly] Auth user created: ${newAuthUser.id} for email ${newAuthUser.email}`);

        // 6. Insert into public.users table (profile)
        console.log("[add-user-directly] Attempting to create profile for:", newAuthUser.id);
        const { error: profileError } = await supabaseAdminClient.from("users").insert({
          id: newAuthUser.id, // Use the ID from the created auth user
          email: newAuthUser.email,
          username: username,
          first_name: firstName,
          last_name: lastName,
          role: role,
          // created_at is handled by db default
        }).select(); // Add .select() to get potential error details better

        if (profileError) {
          console.error("[add-user-directly] Error creating user profile in public.users:", profileError.message, JSON.stringify(profileError));
          // Attempt to clean up the auth user if profile creation fails
          console.log(`[add-user-directly] Attempting to delete auth user ${newAuthUser.id} due to profile error.`);
          await supabaseAdminClient.auth.admin.deleteUser(newAuthUser.id);
          console.log(`[add-user-directly] Cleaned up auth user ${newAuthUser.id}.`);
          throw new Error(`Failed to create user profile: ${profileError.message}`);
        }
        console.log(`[add-user-directly] User profile created in public.users: ${newAuthUser.id}`);

        // 7. If role is 'company', create a company entry
        if (role === 'company' && companyName && companyName.trim() !== '') {
            console.log("[add-user-directly] Attempting to create company for:", newAuthUser.id);
            const { error: companyError } = await supabaseAdminClient.from("companies").insert({
                name: companyName.trim(),
                created_by: newAuthUser.id, // Link company to the new user
            }).select();

            if (companyError) {
                console.error("[add-user-directly] Error creating company profile:", companyError.message, JSON.stringify(companyError));
                // Clean up user profile and auth user
                console.log(`[add-user-directly] Attempting to delete profile and auth user ${newAuthUser.id} due to company error.`);
                await supabaseAdminClient.from("users").delete().eq("id", newAuthUser.id);
                await supabaseAdminClient.auth.admin.deleteUser(newAuthUser.id);
                console.log(`[add-user-directly] Cleaned up user profile and auth user ${newAuthUser.id}.`);
                throw new Error(`Failed to create company profile: ${companyError.message}`);
            }
            console.log(`[add-user-directly] Company profile created for ${newAuthUser.id}`);
        }

        return new Response(JSON.stringify({ message: "User added successfully", userId: newAuthUser.id }), {
          status: 200,
          headers: { "Content-Type": "application/json", "Access-Control-Allow-Origin": "*" },
        });

      } catch (error) {
        console.error("[add-user-directly] Overall Error in function:", error.message, error.stack);
        const errorMessage = error instanceof Error ? error.message : "An unexpected error occurred.";
        const errorStatus = (error as any).status >= 400 && (error as any).status < 500 ? (error as any).status : 500;

        return new Response(JSON.stringify({ error: errorMessage }), {
          status: errorStatus,
          headers: { "Content-Type": "application/json", "Access-Control-Allow-Origin": "*" },
        });
      }
    });
