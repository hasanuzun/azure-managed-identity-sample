using Azure.Identity;
using SampleApi.Helpers;
using SampleApi.Models;

namespace SampleApi;

public static class Program
{
    public static void Main(string[] args)
    {
        var builder = WebApplication.CreateBuilder(args);  
        
        AddKeyVault(builder.Configuration);
        
        // Register appSettings
        builder.Services.AddSingleton(builder.Configuration.Get<AppSettings>()!);
        
        // Add custom helper class to get access tokens
        builder.Services.AddSingleton<IManagedIdentityHelper, ManagedIdentityHelper>();
        
        // Add services to the container.
        builder.Services.AddControllersWithViews();

        var app = builder.Build();

        // Configure the HTTP request pipeline.
        if (!app.Environment.IsDevelopment())
        {
            app.UseExceptionHandler("/Home/Error");
            // The default HSTS value is 30 days. You may want to change this for production scenarios, see https://aka.ms/aspnetcore-hsts.
            app.UseHsts();
        }

        app.UseHttpsRedirection();
        app.UseStaticFiles();

        app.UseRouting();

        app.UseAuthorization();

        app.MapControllerRoute(
            name: "default",
            pattern: "{controller=Home}/{action=Index}/{id?}");

        app.Run();
    }


    private static void AddKeyVault(IConfigurationBuilder configurationBuilder)
    {
        var configuration = configurationBuilder.Build();
        var appSettings = configuration.Get<AppSettings>()!;

        try
        {
            if (string.IsNullOrEmpty(appSettings.KeyVaultName)) return;
            var credentials = string.IsNullOrEmpty(appSettings.ManagedIdentityClientId)
                ? new DefaultAzureCredential()
                : new DefaultAzureCredential(new DefaultAzureCredentialOptions
                    { ManagedIdentityClientId = appSettings.ManagedIdentityClientId });

            configurationBuilder.AddAzureKeyVault(new Uri($"https://{appSettings.KeyVaultName}.vault.azure.net/"),
                credentials);

            Console.WriteLine($"KeyVault[{appSettings.KeyVaultName}] registered!");
        }
        catch (Exception ex)
        {
            Console.Error.WriteLine(
                $"Cannot register KeyVault[{appSettings.KeyVaultName}], error: " + ex.Message
            );
        }
    }
}
