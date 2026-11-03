//creato da Andrea Piani - 03/11/26 - https://www.andreapiani.com - YourProView.swift
//  Talky
//
//  "Il tuo Talky Pro": compare subito dopo l'acquisto, sopra la paywall, e
//  si riapre da Impostazioni. Chi ha pagato deve vedere cosa ha comprato e
//  dove trovarlo, altrimenti meta' delle funzioni restano nascoste in
//  Impostazioni e l'abbonamento sembra valere meno di quanto vale.

import SwiftUI

struct YourProView: View {
    let onDone: () -> Void

    @StateObject private var settingsManager = SettingsManager.shared

    private var isDark: Bool { settingsManager.isDarkModeEnabled }
    // Stessa palette della paywall: e' la sua continuazione.
    private var brand: Color { Color(red: 1.0, green: 0.8, blue: 0.0) }
    private var brandSoft: Color { brand.opacity(isDark ? 0.12 : 0.08) }
    private var background: Color {
        isDark ? Color(red: 0.055, green: 0.051, blue: 0.043) : Color(red: 0.980, green: 0.969, blue: 0.941)
    }
    private var ink: Color {
        isDark ? Color(red: 0.957, green: 0.937, blue: 0.894) : Color(red: 0.086, green: 0.082, blue: 0.075)
    }
    private var inkSecondary: Color {
        isDark ? Color(red: 0.639, green: 0.604, blue: 0.545) : Color(red: 0.361, green: 0.329, blue: 0.290)
    }

    var body: some View {
        ZStack {
            background.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 22) {
                    header
                    VStack(alignment: .leading, spacing: 18) {
                        ForEach(ProPerk.here) { perk in
                            row(perk)
                        }
                    }
                    Text(Tour.text("tour.yourpro.thanks"))
                        .font(.system(size: 13))
                        .foregroundColor(inkSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 72)
                }
                .padding(.horizontal, 20)
                .padding(.top, 28)
            }

            VStack {
                Spacer()
                Button(action: onDone) {
                    Text(Tour.text("tour.yourpro.done"))
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Capsule().fill(brand))
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 12)
            }
        }
        .preferredColorScheme(isDark ? .dark : .light)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(brand)
                    .frame(width: 56, height: 56)
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundColor(.black)
            }
            Text(Tour.text("tour.yourpro.title"))
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .foregroundColor(ink)
            Text(Tour.text("tour.yourpro.subtitle"))
                .font(.system(size: 15))
                .foregroundColor(inkSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func row(_ perk: ProPerk) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: perk.symbol)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(brand)
                .frame(width: 30, height: 30)
                .background(Circle().fill(brandSoft))
            VStack(alignment: .leading, spacing: 3) {
                Text(perk.title(stations: RadioManager.shared.radioStations.count))
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(ink)
                Text(perk.detail)
                    .font(.system(size: 13))
                    .foregroundColor(inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                if let location = perk.location {
                    Label(location, systemImage: "arrow.turn.down.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(isDark ? brand : Color(red: 0.6, green: 0.45, blue: 0.0))
                        .padding(.top, 2)
                }
            }
            Spacer(minLength: 0)
        }
    }
}
