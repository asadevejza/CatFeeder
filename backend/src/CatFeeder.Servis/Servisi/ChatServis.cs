using System.Net.Http.Headers;
using System.Text;
using System.Text.Json;
using Microsoft.Extensions.Configuration;

namespace CatFeeder.Servis.Servisi
{
    public class ChatServis
    {
        private readonly HttpClient _httpClient;
        private readonly string _apiKey;
        private readonly string _model;

        public ChatServis(HttpClient httpClient, IConfiguration config)
        {
            _httpClient = httpClient;
            _apiKey = config["Groq:ApiKey"] ?? throw new InvalidOperationException("Groq:ApiKey nije postavljen u appsettings.json");
            _model = config["Groq:Model"] ?? "llama-3.1-8b-instant";
        }

        public async Task<string> AskAsync(string userMessage, string? catName, string? extraContext)
        {
            var systemPrompt =
                "Ti si pomoćni AI asistent u aplikaciji za pametnu hranilicu za mačke (CatFeeder). " +
                "Odgovaraj kratko, jasno i na bosanskom jeziku. " +
                (string.IsNullOrWhiteSpace(catName) ? "" : $"Mačka o kojoj razgovaramo se zove {catName}. ") +
                (string.IsNullOrWhiteSpace(extraContext) ? "" : $"Dodatni kontekst: {extraContext}. ") +
                "Ako pitanje nije vezano za brigu o mački, ishranu, zdravlje ili hranilicu, kratko to napomeni ali i dalje pokušaj pomoći.";

            var requestBody = new
            {
                model = _model,
                messages = new object[]
                {
                    new { role = "system", content = systemPrompt },
                    new { role = "user", content = userMessage }
                },
                temperature = 0.6
            };

            var json = JsonSerializer.Serialize(requestBody);
            using var request = new HttpRequestMessage(HttpMethod.Post, "https://api.groq.com/openai/v1/chat/completions");
            request.Headers.Authorization = new AuthenticationHeaderValue("Bearer", _apiKey);
            request.Content = new StringContent(json, Encoding.UTF8, "application/json");

            var response = await _httpClient.SendAsync(request);
            var responseBody = await response.Content.ReadAsStringAsync();

            if (!response.IsSuccessStatusCode)
                throw new Exception($"Groq API greška ({response.StatusCode}): {responseBody}");

            using var doc = JsonDocument.Parse(responseBody);
            var reply = doc.RootElement
                .GetProperty("choices")[0]
                .GetProperty("message")
                .GetProperty("content")
                .GetString();

            return reply ?? "Nisam uspio generisati odgovor.";
        }
    }
}