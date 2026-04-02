//
//  CertificatesView.swift
//  Feather778
//

import SwiftUI
import NimbleViews
import NimbleExtensions
import CoreData

struct CertificatesView: View {
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \CertificatePair.date, ascending: false)],
        animation: .default
    )
    private var certificates: FetchedResults<CertificatePair>

    @Binding var selection: Int
    @State private var showAddCert = false
    @State private var selectedCert: CertificatePair?
    @State private var showInfo = false
    @State private var showDeleteAlert = false
    @State private var certToDelete: CertificatePair?

    private var _isEmbedded: Bool

    init(selection: Binding<Int>? = nil) {
        if let sel = selection {
            _selection = sel
            _isEmbedded = true
        } else {
            _selection = .constant(-1)
            _isEmbedded = false
        }
    }

    var body: some View {
        NavigationView {
            ScrollView {
                if certificates.isEmpty {
                    VStack(spacing: 16) {
                        Spacer().frame(height: 80)
                        Image(systemName: "person.text.rectangle")
                            .font(.system(size: 52))
                            .foregroundColor(.secondary.opacity(0.4))
                        Text("No Certificates")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.secondary)
                        Text("Import a P12 certificate with its\nmobile provisioning profile")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary.opacity(0.7))
                            .multilineTextAlignment(.center)

                        Button(action: { showAddCert = true }) {
                            Label("Import Certificate", systemImage: "plus.circle.fill")
                                .font(.system(size: 15, weight: .semibold))
                                .padding(.horizontal, 20)
                                .padding(.vertical, 10)
                                .background(Color.accentColor)
                                .foregroundColor(.white)
                                .cornerRadius(20)
                        }
                        .padding(.top, 8)
                    }
                    .frame(maxWidth: .infinity)
                } else {
                    LazyVStack(spacing: 14) {
                        ForEach(Array(certificates.enumerated()), id: \.element.uuid) { index, cert in
                            CertificateCardView(
                                cert: cert,
                                isSelected: _isEmbedded && selection == index
                            ) {
                                if _isEmbedded {
                                    selection = index
                                    UserDefaults.standard.set(index, forKey: "feather.selectedCert")
                                } else {
                                    selectedCert = cert
                                    showInfo = true
                                }
                            } onDelete: {
                                if !cert.isDefault {
                                    certToDelete = cert
                                    showDeleteAlert = true
                                } else {
                                    ToastManager.shared.show("Cannot delete default certificate", style: .error)
                                }
                            } onCheckRevoke: {
                                Storage.shared.revokagedCertificate(for: cert)
                                ToastManager.shared.show("Checking revocation status...", style: .info)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                }
            }
            .navigationTitle("Certificates")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showAddCert = true }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                    }
                }
            }
            .sheet(isPresented: $showAddCert) {
                CertificatesAddView()
            }
            .sheet(isPresented: $showInfo) {
                if let cert = selectedCert {
                    CertificatesInfoView(cert: cert)
                }
            }
            .alert("Delete Certificate", isPresented: $showDeleteAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    if let cert = certToDelete {
                        Storage.shared.deleteCertificate(for: cert)
                        ToastManager.shared.show("Certificate deleted", style: .success)
                    }
                }
            } message: {
                Text("Are you sure you want to delete this certificate?")
            }
        }
        .navigationViewStyle(.stack)
        .withToast()
    }
}

// MARK: - Certificate Card View
struct CertificateCardView: View {
    let cert: CertificatePair
    let isSelected: Bool
    let onTap: () -> Void
    let onDelete: () -> Void
    let onCheckRevoke: () -> Void

    @State private var decoded: Certificate?

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Image(systemName: "person.text.rectangle.fill")
                        .font(.system(size: 28))
                        .foregroundColor(.accentColor)

                    Spacer()

                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.system(size: 20))
                    }

                    Menu {
                        Button("View Details", systemImage: "info.circle") { onTap() }
                        Button("Check Revocation", systemImage: "shield.checkered") { onCheckRevoke() }
                        Divider()
                        Button("Delete", systemImage: "trash", role: .destructive) { onDelete() }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .foregroundColor(.secondary)
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(cert.nickname ?? decoded?.Name ?? "Certificate")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.primary)
                        .lineLimit(1)

                    if let decoded = decoded {
                        Text(decoded.AppIDName)
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }

                HStack(spacing: 8) {
                    // Expiration status
                    _statusPill()

                    if let ppq = decoded?.PPQCheck, ppq {
                        _pill("PPQ", color: .orange)
                    }

                    if let taskAllow = decoded?.Entitlements?["get-task-allow"]?.value as? Bool, taskAllow {
                        _pill("Debug", color: .purple)
                    }
                }
            }
            .padding(16)
            .background(Color(UIColor.secondarySystemGroupedBackground))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
            )
            .cornerRadius(14)
            .shadow(color: .black.opacity(0.06), radius: 6, y: 2)
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button("View Details", systemImage: "info.circle") { onTap() }
            Button("Check Revocation", systemImage: "shield.checkered") { onCheckRevoke() }
            Divider()
            Button("Delete", systemImage: "trash", role: .destructive) { onDelete() }
        }
        .onAppear {
            decoded = Storage.shared.getProvisionFileDecoded(for: cert)
        }
    }

    @ViewBuilder
    private func _statusPill() -> some View {
        if cert.revoked {
            _pill("Revoked", color: .red)
        } else {
            let info = cert.expiration?.expirationInfo()
            let isExpired = info?.color == .red
            _pill(
                isExpired ? "Expired" : "Valid",
                color: isExpired ? .red : .green
            )
        }
    }

    @ViewBuilder
    private func _pill(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .bold))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.15))
            .foregroundColor(color)
            .cornerRadius(6)
    }
}
