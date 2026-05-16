//
//  SupabaseManager.swift
//  Home Management
//
//  Created by Jared Nash on 2/4/26.
//
import Foundation

#if canImport(Supabase)
import Supabase
#endif

// Centralized configuration for Supabase
private enum SupabaseConfig {
    // Load URL from Secrets.plist file lazily
    static let url: URL = {
        guard
            let path = Bundle.main.path(forResource: "Secrets", ofType: "plist"),
            let dict = NSDictionary(contentsOfFile: path),
            let urlString = dict["SUPABASE_URL"] as? String,
            let url = URL(string: urlString)
        else {
            fatalError("Supabase URL not found in Secrets.plist")
        }
        return url
    }()
    
    // Load anonKey from Secrets.plist file lazily
    static let anonKey: String = {
        guard
            let path = Bundle.main.path(forResource: "Secrets", ofType: "plist"),
            let dict = NSDictionary(contentsOfFile: path),
            let key = dict["SUPABASE_ANON_KEY"] as? String
        else {
            fatalError("Supabase anon key not found in Secrets.plist")
        }
        return key
    }()
}

// Provide a minimal fallback type so the project compiles even if the Supabase package isn't linked.
#if !canImport(Supabase)
public struct SupabaseClient {
    public init(supabaseURL: URL, supabaseKey: String) {
        // Fallback no-op initializer for builds without the Supabase package
        _ = (supabaseURL, supabaseKey)
    }
}
// Minimal fallback LocalStorage protocol and no-op storage so the file compiles without Supabase
public protocol LocalStorage {}
public struct NoopLocalStorage: LocalStorage {
    public init() {}
}
#endif

final class SupabaseManager {
    static let shared = SupabaseManager()

    let client: SupabaseClient

    private init() {
        #if canImport(Supabase)
        // Build Auth configuration per request, opting into the new behavior
        let supabaseURL = SupabaseConfig.url
        let anonKey = SupabaseConfig.anonKey

        let authOptions = SupabaseClientOptions.AuthOptions(
            storage: KeychainLocalStorage(),
            flowType: .pkce,
            autoRefreshToken: true,
            emitLocalSessionAsInitialSession: true
        )

        let options = SupabaseClientOptions(
            auth: authOptions
        )

        client = SupabaseClient(
            supabaseURL: supabaseURL,
            supabaseKey: anonKey,
            options: options
        )
        #else
        client = SupabaseClient(
            supabaseURL: SupabaseConfig.url,
            supabaseKey: SupabaseConfig.anonKey
        )
        #endif
    }
}

