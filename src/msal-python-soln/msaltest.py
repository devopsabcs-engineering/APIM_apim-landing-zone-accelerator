from msal import PublicClientApplication

app = PublicClientApplication(
    "f9371abf-e2c9-4e5f-b4d8-9f7d93e2fd4c",
    authority="https://login.microsoftonline.com/common")

# initialize result variable to hole the token response
result = None

# We now check the cache to see
# whether we already have some accounts that the end user already used to sign in before.
accounts = app.get_accounts()
if accounts:
    # If so, you could then somehow display these accounts and let end user choose
    print("Pick the account you want to use to proceed:")
    for a in accounts:
        print(a["username"])
    # Assuming the end user chose this one
    chosen = accounts[0]
    # Now let's try to find a token in cache for this account
    result = app.acquire_token_silent(["User.Read"], account=chosen)

if not result:
    # So no suitable token exists in cache. Let's get a new one from Azure AD.
    result = app.acquire_token_interactive(scopes=["User.Read"])
if "access_token" in result:
    print(result["access_token"])  # Yay!
else:
    print(result.get("error"))
    print(result.get("error_description"))
    # You may need this when reporting a bug
    print(result.get("correlation_id"))
