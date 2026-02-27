import AppKit
import SwiftUI

enum AppScreen {
    case mainMenu
    case tetris
    case matrix
    case rainUmbrella
    case audioVisualizer
    case inkWave
    case neonGravity
    case voronoiCell
    case lightningGenerator
    case fireworks
    case smokeFog
    case auroraSky
    case laserMirrorPuzzle
    case fractalZoom
}

struct ContentView: View {
    @State private var screen: AppScreen = .mainMenu

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.04, green: 0.06, blue: 0.12), Color(red: 0.10, green: 0.07, blue: 0.14)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            switch screen {
            case .mainMenu:
                mainMenuView
            case .tetris:
                TetrisFeatureView(
                    onBackToMainMenu: {
                        screen = .mainMenu
                    },
                    onQuitApp: {
                        NSApplication.shared.terminate(nil)
                    }
                )
            case .matrix:
                MatrixPortalView(
                    onBackToMainMenu: {
                        screen = .mainMenu
                    }
                )
            case .rainUmbrella:
                RainUmbrellaView(
                    onBackToMainMenu: {
                        screen = .mainMenu
                    }
                )
            case .audioVisualizer:
                AudioVisualizerToyView(
                    onBackToMainMenu: {
                        screen = .mainMenu
                    }
                )
            case .inkWave:
                InkWaveToyView(
                    onBackToMainMenu: {
                        screen = .mainMenu
                    }
                )
            case .neonGravity:
                NeonParticleGravityToyView(
                    onBackToMainMenu: {
                        screen = .mainMenu
                    }
                )
            case .voronoiCell:
                VoronoiCellToyView(
                    onBackToMainMenu: {
                        screen = .mainMenu
                    }
                )
            case .lightningGenerator:
                LightningGeneratorToyView(
                    onBackToMainMenu: {
                        screen = .mainMenu
                    }
                )
            case .fireworks:
                FireworksToyView(
                    onBackToMainMenu: {
                        screen = .mainMenu
                    }
                )
            case .smokeFog:
                SmokeFogVolumetricToyView(
                    onBackToMainMenu: {
                        screen = .mainMenu
                    }
                )
            case .auroraSky:
                AuroraSkyToyView(
                    onBackToMainMenu: {
                        screen = .mainMenu
                    }
                )
            case .laserMirrorPuzzle:
                LaserMirrorPuzzleToyView(
                    onBackToMainMenu: {
                        screen = .mainMenu
                    }
                )
            case .fractalZoom:
                FractalZoomToyView(
                    onBackToMainMenu: {
                        screen = .mainMenu
                    }
                )
            }
        }
        .frame(minWidth: 760, minHeight: 820)
    }

    private var mainMenuView: some View {
        VStack(spacing: 14) {
            Text("GAME MENU")
                .font(.system(size: 52, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)

            ScrollView(.vertical, showsIndicators: true) {
                VStack(spacing: 16) {
                    Button("1. 테트리스") {
                        screen = .tetris
                    }
                    .buttonStyle(MainMenuButtonStyle())

                    Button("2. 매트릭스 이펙트") {
                        screen = .matrix
                    }
                    .buttonStyle(MainMenuButtonStyle())

                    Button("3. 우산 레인") {
                        screen = .rainUmbrella
                    }
                    .buttonStyle(MainMenuButtonStyle())

                    Button("4. 오디오 비주얼라이저") {
                        screen = .audioVisualizer
                    }
                    .buttonStyle(MainMenuButtonStyle())

                    Button("5. 유체/잉크 파동") {
                        screen = .inkWave
                    }
                    .buttonStyle(MainMenuButtonStyle())

                    Button("6. 네온 파티클 중력 놀이터") {
                        screen = .neonGravity
                    }
                    .buttonStyle(MainMenuButtonStyle())

                    Button("7. 보로노이(세포) 애니메이션") {
                        screen = .voronoiCell
                    }
                    .buttonStyle(MainMenuButtonStyle())

                    Button("8. 라이팅닝(번개) 생성기") {
                        screen = .lightningGenerator
                    }
                    .buttonStyle(MainMenuButtonStyle())

                    Button("9. 불꽃놀이 시뮬레이터") {
                        screen = .fireworks
                    }
                    .buttonStyle(MainMenuButtonStyle())

                    Button("10. 연기/안개 볼류메트릭 이펙트") {
                        screen = .smokeFog
                    }
                    .buttonStyle(MainMenuButtonStyle())

                    Button("11. 오로라 스카이 생성기") {
                        screen = .auroraSky
                    }
                    .buttonStyle(MainMenuButtonStyle())

                    Button("12. 레이저 거울 반사 퍼즐 토이") {
                        screen = .laserMirrorPuzzle
                    }
                    .buttonStyle(MainMenuButtonStyle())

                    Button("13. 프랙탈 줌(만델브로/줄리아) 뷰어") {
                        screen = .fractalZoom
                    }
                    .buttonStyle(MainMenuButtonStyle())

                    Button("종료") {
                        NSApplication.shared.terminate(nil)
                    }
                    .buttonStyle(SecondaryMenuButtonStyle())
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
            }
            .frame(maxWidth: 620, maxHeight: 560)
        }
        .padding(.vertical, 16)
    }
}

private struct MainMenuButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 24, weight: .bold, design: .rounded))
            .foregroundStyle(.white)
            .padding(.horizontal, 28)
            .padding(.vertical, 14)
            .background(
                Color(red: 0.16, green: 0.64, blue: 0.88)
                    .opacity(configuration.isPressed ? 0.76 : 1.0),
                in: RoundedRectangle(cornerRadius: 12)
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
    }
}

private struct SecondaryMenuButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 18, weight: .semibold, design: .rounded))
            .foregroundStyle(.white)
            .padding(.horizontal, 22)
            .padding(.vertical, 10)
            .background(
                Color.white.opacity(configuration.isPressed ? 0.14 : 0.22),
                in: RoundedRectangle(cornerRadius: 10)
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
