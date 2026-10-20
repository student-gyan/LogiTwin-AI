
package com.logitwin.api.ai;

import com.fasterxml.jackson.databind.JsonNode;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.web.client.ResourceAccessException;
import org.springframework.web.client.RestClientException;
import org.springframework.web.client.RestTemplate;
import org.springframework.web.server.ResponseStatusException;

@Service
public class PythonAiService {

    private final RestTemplate restTemplate = new RestTemplate();

    @Value("${logi-twin.ai-base-url:http://127.0.0.1:8000}")
    private String aiBaseUrl;

    public JsonNode optimizeRoute(JsonNode request) {
        try {
            JsonNode result = restTemplate.postForObject(
                aiBaseUrl + "/api/ai/routes/optimize",
                request,
                JsonNode.class
            );

            if (result == null) {
                throw new ResponseStatusException(
                    HttpStatus.BAD_GATEWAY,
                    "Python AI returned an empty response"
                );
            }

            return result;

        } catch (ResourceAccessException ex) {
            throw new ResponseStatusException(
                HttpStatus.BAD_GATEWAY,
                "Cannot connect to Python AI service at " + aiBaseUrl
            );
        } catch (RestClientException ex) {
            throw new ResponseStatusException(
                HttpStatus.BAD_GATEWAY,
                "Python AI request failed: " + ex.getMessage()
            );
        }
    }
}
