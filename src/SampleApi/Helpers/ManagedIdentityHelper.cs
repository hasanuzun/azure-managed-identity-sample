using Azure.Core;
using Azure.Identity;
using SampleApi.Models;

namespace SampleApi.Helpers;

public interface IManagedIdentityHelper
{
    Task<string?> GetDbAccessToken();
}

public class ManagedIdentityHelper(
    AppSettings appSettings,
    ILogger<ManagedIdentityHelper> logger) : IManagedIdentityHelper
{
    public async Task<string?> GetDbAccessToken()
    {
        // Azure AD resource ID for Azure Database for PostgreSQL Flexible Server is https://ossrdbms-aad.database.windows.net/
        string accessToken = null;

        try
        {
            logger.LogInformation("Creating access token with managed identity: " +
                                  appSettings.ManagedIdentityClientId);

            var tokenOptions = new DefaultAzureCredentialOptions
            {
                ManagedIdentityClientId = appSettings.ManagedIdentityClientId
            };

            var tokenProvider = new DefaultAzureCredential(tokenOptions);

            var tokenResponse = await tokenProvider.GetTokenAsync(
                new TokenRequestContext(scopes: ["https://ossrdbms-aad.database.windows.net/.default"]));

            accessToken = tokenResponse.Token;

            logger.LogInformation($"Access token created: {accessToken.Substring(0, 5)}...");
        }
        catch (Exception e)
        {
            logger.LogError(e, "{0} \n\n{1}", e.Message,
                e.InnerException != null ? e.InnerException.Message : "Acquire token failed");
        }

        return accessToken;
    }
}