namespace SampleApi.Models;

public class AppSettings
{
    public string KeyVaultName { get; set; }
    public string PostgresConnectionString { get; set; } 
    
    public string ManagedIdentityClientId { get; set; } 
}