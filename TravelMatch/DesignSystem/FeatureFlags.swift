import Foundation

/// Kademeli açılan özellikler.
enum FeatureFlags {
    /// Sohbette fotoğraf gönderme. Depolama Firebase Storage'dan Supabase'e
    /// taşındı ve çalışıyor (bkz. SupabaseDepo), bu yüzden açık.
    static let photoMessagingEnabled = true
}
