package com.b2b.learning.identity.dto;

import java.util.List;

public record MeResponse(
    String username,
    List<String> roles
) {}
