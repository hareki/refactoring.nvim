package org.example;

public class App {

    public static void main(String[] args) {

        System.out.println("foo");

        while (true) {
            System.out.println("foo");
            break;
        }

        do {
            System.out.println("foo");
        } while (false);

        if (true) {
            System.out.println("foo");
        } else {
            System.out.println("foo");
        }

        for (int i = 0; i < 5; i++) {
            System.out.println("foo");
        }

    }
}
