using System.Diagnostics;
using System.Text;
using Microsoft.AspNetCore.Mvc;
using Npgsql;
using SampleApi.Helpers;
using SampleApi.Models;

namespace SampleApi.Controllers;

public class HomeController(
    ILogger<HomeController> logger,  
    AppSettings appSettings,
    IManagedIdentityHelper managedIdentityHelper) : Controller
{
    public async Task<IActionResult> Index()
    {
        var model = new IndexViewModel();
        model.SqlQuery = "SELECT version()";
       
        ArgumentException.ThrowIfNullOrWhiteSpace(appSettings.PostgresConnectionString, nameof(appSettings.PostgresConnectionString));
        
        var connStringBuilder = new NpgsqlConnectionStringBuilder(appSettings.PostgresConnectionString);

        if (!string.IsNullOrEmpty(appSettings.ManagedIdentityClientId))
        {
            connStringBuilder.Password = await managedIdentityHelper.GetDbAccessToken();
        }

        var connString = connStringBuilder.ToString();

        try
        {
            await using var conn = new NpgsqlConnection(connString);
            logger.LogInformation("Opening connection using access token...");
            await conn.OpenAsync();
            logger.LogInformation("Db connection opened with access token...");

            await using var command = new NpgsqlCommand(    model.SqlQuery , conn);
            var reader = await command.ExecuteReaderAsync();

            var queryResults = new StringBuilder();
            
            while (reader.Read())
            {
                queryResults.AppendLine(reader.GetString(0));
            }

            model.SqlQueryResult = queryResults.ToString();
        }
        catch (Exception e)
        {
            logger.LogError(e,
                $"Cannot connect postgres, user: {connStringBuilder.Username}, db: {connStringBuilder.Database} server: {connStringBuilder.Host}");
        }

        return View(model);
    }

    public IActionResult Privacy()
    {
        return View();
    }

    [ResponseCache(Duration = 0, Location = ResponseCacheLocation.None, NoStore = true)]
    public IActionResult Error()
    {
        return View(new ErrorViewModel { RequestId = Activity.Current?.Id ?? HttpContext.TraceIdentifier });
    }
}
