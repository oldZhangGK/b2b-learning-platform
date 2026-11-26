package com.b2b.learning.identity.init;

import com.b2b.learning.identity.domain.Account;
import com.b2b.learning.identity.domain.Role;
import com.b2b.learning.identity.repository.AccountRepository;
import com.b2b.learning.identity.repository.RoleRepository;
import org.springframework.boot.ApplicationArguments;
import org.springframework.boot.ApplicationRunner;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Component;

import java.util.Set;

// Seeds a demo ADMIN account on startup if one does not already exist.
// Credentials: admin / Admin@123
@Component
public class DataInitializer implements ApplicationRunner {

    private final AccountRepository accountRepository;
    private final RoleRepository roleRepository;
    private final PasswordEncoder passwordEncoder;

    public DataInitializer(AccountRepository accountRepository,
                           RoleRepository roleRepository,
                           PasswordEncoder passwordEncoder) {
        this.accountRepository = accountRepository;
        this.roleRepository = roleRepository;
        this.passwordEncoder = passwordEncoder;
    }

    @Override
    public void run(ApplicationArguments args) {
        if (accountRepository.existsByUsername("admin")) return;

        Role adminRole = roleRepository.findByName("ADMIN")
            .orElseThrow(() -> new IllegalStateException("ADMIN role not seeded — Flyway V1 may not have run"));

        Account admin = new Account();
        admin.setUsername("admin");
        admin.setEmail("admin@example.com");
        admin.setPasswordHash(passwordEncoder.encode("Admin@123"));
        admin.setEnabled(true);
        admin.setRoles(Set.of(adminRole));
        accountRepository.save(admin);
    }
}
