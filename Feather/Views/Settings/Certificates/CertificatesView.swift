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
    private var _skipNavigationView: Bool

    init(selection: Binding<Int>? = nil, embedded: Bool = false) {
        if let sel = selection {
            _selection = sel
            _isEmbedded = true
        } else {
            _selection = .constant(-1)
            _isEmbedded = false
        }
        _skipNavigationView = embedded
    }

    var body: some View {
        if _skipNavigationView {
            _content()
        } else {
            NavigationView {
                _content()
            }
            .navigationViewStyle(.stack)
            .withToast()
        }
    }

    @ViewBuilder
    private func _content() -> some View {
        ScrollView {
            if certificates.isEmpty {
                VStack(spacing: 16) {
                    Spacer().frame(height: 80)
                    Image(systemName: "person.text.rectangle")
                        .font(.system(size: 52))
                        .foregroundColor(.secondary.opacity(0.4))
                    Text("暂无证书")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.secondary)
                    Text("请导入 P12 证书及其\n描述文件")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary.opacity(0.7))
                        .multilineTextAlignment(.center)

                    Button(action: { showAddCert = true }) {
                        Label("导入证书", systemImage: "plus.circle.fill")
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
                                ToastManager.shared.show("无法删除默认证书", style: .error)
                            }
                        } onCheckRevoke: {
                            Storage.shared.revokagedCertificate(for: cert)
                            ToastManager.shared.show("正在检查吊销状态...", style: .info)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
            }
        }
        .navigationTitle("证书")
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
        .alert("删除证书", isPresented: $showDeleteAlert) {
            Button("取消", role: .cancel) { }
            Button("删除", role: .destructive) {
                if let cert = certToDelete {
                    Storage.shared.deleteCertificate(for: cert)
                    ToastManager.shared.show("证书已删除", style: .success)
                }
            }
        } message: {
            Text("确定要删除此证书吗？")
        }
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
                        Button("查看详情", systemImage: "info.circle") { onTap() }
                        Button("检查吊销", systemImage: "shield.checkered") { onCheckRevoke() }
                        Divider()
                        Button("删除", systemImage: "trash", role: .destructive) { onDelete() }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .foregroundColor(.secondary)
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(cert.nickname ?? decoded?.Name ?? "证书")
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
                    _statusPill()

                    if let ppq = decoded?.PPQCheck, ppq {
                        _pill("PPQ", color: .orange)
                    }

                    if let taskAllow = decoded?.Entitlements?["get-task-allow"]?.value as? Bool, taskAllow {
                        _pill("调试", color: .purple)
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
            Button("查看详情", systemImage: "info.circle") { onTap() }
            Button("检查吊销", systemImage: "shield.checkered") { onCheckRevoke() }
            Divider()
            Button("删除", systemImage: "trash", role: .destructive) { onDelete() }
        }
        .onAppear {
            decoded = Storage.shared.getProvisionFileDecoded(for: cert)
        }
    }

    @ViewBuilder
    private func _statusPill() -> some View {
        if cert.revoked {
            _pill("已吊销", color: .red)
        } else {
            let info = cert.expiration?.expirationInfo()
            let isExpired = info?.color == .red
            _pill(
                isExpired ? "已过期" : "有效",
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
