package com.example.kitcheck;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.scheduling.annotation.EnableScheduling;

@SpringBootApplication
@EnableScheduling
public class KitCheckApplication {

    public static void main(String[] args) {
        SpringApplication.run(KitCheckApplication.class, args);
    }
}
