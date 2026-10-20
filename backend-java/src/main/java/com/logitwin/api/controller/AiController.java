
package com.logitwin.api.controller;

import com.fasterxml.jackson.databind.JsonNode;
import com.logitwin.api.ai.PythonAiService;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/ai")
public class AiController {

    private final PythonAiService pythonAiService;

    public AiController(PythonAiService pythonAiService) {
        this.pythonAiService = pythonAiService;
    }

    @PostMapping("/routes/optimize")
    public JsonNode optimizeRoute(@RequestBody JsonNode request) {
        return pythonAiService.optimizeRoute(request);
    }
}
