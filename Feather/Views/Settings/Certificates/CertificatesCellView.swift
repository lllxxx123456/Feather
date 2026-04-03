//
//  CertificatesCellView.swift
//  Feather778
//

import SwiftUI
import NimbleExtensions

// Kept for compatibility - main display uses CertificateCardView
struct CertificatesCellView: View {
    let cert: CertificatePair
    @State private var decoded: Certificate?

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "person.text.rectangle.fill")
                .font(.system(size: 24))
                .foregroundColor(.accentColor)

            VStack(alignment: .leading, spacing: 3) {
                Text(cert.nickname ?? decoded?.Name ?? "证书")
                    .font(.system(size: 14, weight: .medium))

                if let decoded = decoded {
                    Text(decoded.AppIDName)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            FRExpirationPillView(
                title: "有效",
                revoked: cert.revoked,
                expiration: cert.expiration?.expirationInfo()
            )
        }
        .onAppear {
            decoded = Storage.shared.getProvisionFileDecoded(for: cert)
        }
    }
}
