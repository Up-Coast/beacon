// "Who is this from", asked once.
//
// Shown on the first screen and again on the form, filled in from what the
// reporter gave last time. Nothing here is required: sending without a name
// is a button of its own, so staying anonymous is a choice the reporter
// makes rather than a field they leave blank and wonder about.

import SwiftUI
import BeaconCore
import BeaconGitHub

struct IdentityBlock: View {
    @Bindable var session: FeedbackSession
    let gitHubAccount: GitHubAccount?
    @State private var signingIn = false

    var body: some View {
        if session.asksForIdentity {
            VStack(alignment: .leading, spacing: 10) {
                Text(session.words.identityLabel).font(.headline)
                    .fixedSize(horizontal: false, vertical: true)
                if session.sendsWithoutName {
                    Text(session.words.withoutNameNote)
                        .font(.subheadline).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Button(session.words.addNameButton) { session.chooseToAddName() }
                        .buttonStyle(.bordered)
                } else {
                    FieldBlock(label: session.words.nameLabel, hint: nil) {
                        TextField("", text: $session.name).textFieldStyle(.plain)
                    }
                    FieldBlock(label: session.words.emailLabel, hint: nil) {
                        TextField("", text: $session.contact).textFieldStyle(.plain)
                    }
                    FlowingButtons {
                        Button(session.words.withoutNameButton) { session.chooseToSendWithoutName() }
                        if !session.name.isEmpty || !session.contact.isEmpty {
                            Button(session.words.forgetButton) { session.clearIdentity() }
                        }
                        if gitHubAccount != nil {
                            Button("Sign in with GitHub instead") { signingIn = true }
                        }
                    }
                    .buttonStyle(.bordered)
                }
            }
            .sheet(isPresented: $signingIn) {
                if let gitHubAccount {
                    GitHubSignInView(account: gitHubAccount) {
                        signingIn = false
                        Task {
                            if let reporter = await gitHubAccount.reporterWithProfile() {
                                session.adoptGitHub(reporter)
                            }
                        }
                    }
                    .frame(minWidth: 420, minHeight: 320)
                }
            }
        }
    }
}
