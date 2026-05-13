//
//  UsernameValidationTests.swift
//  FIN1Tests
//
//  Created by ra on 17.08.25.
//

@testable import FIN1
import Testing

struct UsernameValidationTests {
    
    @Test func testValidUsernames() async throws {
        let signUpData = SignUpData()
        
        // Test valid usernames
        let validUsernames = ["test", "user123", "abc123", "TestUser", "user1234", "abcdefghij"]
        
        for username in validUsernames {
            signUpData.username = username
            #expect(signUpData.isUsernameValid == true, "Username '\(username)' should be valid")
        }
    }
    
    @Test func testInvalidUsernames() async throws {
        let signUpData = SignUpData()
        
        // Test invalid usernames
        let invalidUsernames = [
            "abc", // too short (3 chars)
            "abcdefghijk", // too long (11 chars)
            "user@123", // contains special character
            "user-123", // contains special character
            "user 123", // contains space
            "", // empty
            "user_name", // contains underscore
            "user.name" // contains dot
        ]
        
        for username in invalidUsernames {
            signUpData.username = username
            #expect(signUpData.isUsernameValid == false, "Username '\(username)' should be invalid")
        }
    }
    
    @Test func testUsernameLengthValidation() async throws {
        let signUpData = SignUpData()
        
        // Test minimum length (4 characters)
        signUpData.username = "abc"
        #expect(signUpData.isUsernameValid == false, "3 characters should be invalid")
        
        signUpData.username = "abcd"
        #expect(signUpData.isUsernameValid == true, "4 characters should be valid")
        
        // Test maximum length (10 characters)
        signUpData.username = "abcdefghij"
        #expect(signUpData.isUsernameValid == true, "10 characters should be valid")
        
        signUpData.username = "abcdefghijk"
        #expect(signUpData.isUsernameValid == false, "11 characters should be invalid")
    }
    
    @Test func testUsernameCharacterValidation() async throws {
        let signUpData = SignUpData()
        
        // Test alphanumeric characters only
        signUpData.username = "user123"
        #expect(signUpData.isUsernameValid == true, "Alphanumeric should be valid")
        
        signUpData.username = "USER123"
        #expect(signUpData.isUsernameValid == true, "Uppercase alphanumeric should be valid")
        
        signUpData.username = "User123"
        #expect(signUpData.isUsernameValid == true, "Mixed case alphanumeric should be valid")
        
        // Test special characters (should be invalid)
        signUpData.username = "user@123"
        #expect(signUpData.isUsernameValid == false, "Special character @ should be invalid")
        
        signUpData.username = "user-123"
        #expect(signUpData.isUsernameValid == false, "Special character - should be invalid")
        
        signUpData.username = "user_123"
        #expect(signUpData.isUsernameValid == false, "Special character _ should be invalid")
        
        signUpData.username = "user.123"
        #expect(signUpData.isUsernameValid == false, "Special character . should be invalid")
    }
}
