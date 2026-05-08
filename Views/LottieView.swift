//
//  LottieView.swift
//  BlockBlast
//
//  A SwiftUI-friendly wrapper around Lottie's `LottieAnimationView`. Lottie
//  ships a UIKit view, so we bridge it with `UIViewRepresentable`. The
//  wrapper supports:
//    • Looping or one-shot playback
//    • `onComplete` callback (great for dismissing the game-over overlay)
//    • Replaying when the bound `playToken` value changes (so the same Lottie
//      can fire repeatedly without the parent recreating the view).
//

import SwiftUI
import UIKit
import Lottie

struct LottieView: UIViewRepresentable {

    /// Bundle resource name without the `.json` extension.
    let animationName: String
    /// `.loop` for ambient effects, `.playOnce` for fire-and-forget bursts.
    let loopMode: LottieLoopMode
    /// Increment to retrigger playback from frame 0. Useful for combo bursts.
    let playToken: Int
    /// Fired when a `.playOnce` animation finishes naturally.
    var onComplete: (() -> Void)? = nil

    init(
        animationName: String,
        loopMode: LottieLoopMode = .playOnce,
        playToken: Int = 0,
        onComplete: (() -> Void)? = nil
    ) {
        self.animationName = animationName
        self.loopMode = loopMode
        self.playToken = playToken
        self.onComplete = onComplete
    }

    func makeUIView(context: Context) -> UIView {
        // We embed the LottieAnimationView in a plain UIView so AutoLayout can
        // resize the animation to whatever frame SwiftUI hands us.
        let container = UIView(frame: .zero)
        container.backgroundColor = .clear
        container.isUserInteractionEnabled = false

        // Lottie 4.x loads assets via `LottieAnimation` (the old `name:` UIView init was removed).
        let animation = LottieAnimation.named(animationName, bundle: .main)
        let animationView = LottieAnimationView(animation: animation)
        animationView.contentMode = .scaleAspectFit
        animationView.loopMode = loopMode
        animationView.backgroundBehavior = .pauseAndRestore
        animationView.translatesAutoresizingMaskIntoConstraints = false

        container.addSubview(animationView)
        NSLayoutConstraint.activate([
            animationView.topAnchor.constraint(equalTo: container.topAnchor),
            animationView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            animationView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            animationView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
        ])

        context.coordinator.animationView = animationView
        context.coordinator.lastPlayToken = playToken
        animationView.play { finished in
            if finished { context.coordinator.parent.onComplete?() }
        }
        return container
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.parent = self
        guard let animationView = context.coordinator.animationView else { return }

        animationView.loopMode = loopMode

        // Replay only when the parent bumps the play token. Without this guard
        // every unrelated SwiftUI update would restart the animation.
        if playToken != context.coordinator.lastPlayToken {
            context.coordinator.lastPlayToken = playToken
            animationView.stop()
            animationView.play { finished in
                if finished { context.coordinator.parent.onComplete?() }
            }
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator {
        var parent: LottieView
        weak var animationView: LottieAnimationView?
        var lastPlayToken: Int = 0
        init(_ parent: LottieView) { self.parent = parent }
    }
}
