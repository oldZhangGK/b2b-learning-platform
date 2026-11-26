package com.b2b.learning.identity.dto;

import java.util.List;

public record LoginResponse(
    String token,
    String username,
    List<String> roles
) {}
