import Foundation

/// Blaze faturalandırma planı aktif olana kadar bazı özellikler devre dışı.
/// Blaze aktif olduğunda burada `true` yap, ilgili UI otomatik geri açılır.
enum FeatureFlags {
    /// Sohbette fotoğraf gönderme — Firebase Storage bucket'ı henüz oluşturulamadı
    /// (Blaze plan gerekiyor). Storage hazır olunca `true` yap.
    static let photoMessagingEnabled = false
}
