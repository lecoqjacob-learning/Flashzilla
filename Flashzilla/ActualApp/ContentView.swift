
import SwiftUI

extension View {
    func stacked(at position: Int, in total: Int) -> some View {
        let offset = CGFloat(total - position)
        return self.offset(CGSize(width: 0, height: offset * 10))
    }
}

struct ActionButton: View {
    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .padding()
                .background(Color.black.opacity(0.7))
                .clipShape(Circle())
        }
        .foregroundColor(.white)
        .font(.largeTitle)
    }
}

enum SheetType: Hashable, Identifiable {
  case edit, settings

  var id: SheetType { self }
}

struct ContentView: View {
    @Environment(\.accessibilityDifferentiateWithoutColor) var differentiateWithoutColor
    @Environment(\.accessibilityEnabled) var accessibilityEnabled

    @State private var cards = [Card]()
    @State private var timeRemaining = 100
    @State private var isActive = true

    // Challenge 1
    var haptics = Haptics()
    @State private var initialCardsCount = 0
    @State private var correctCards = 0
    @State private var incorrectCards = 0
    private var reviewedCards: Int {
        correctCards + incorrectCards
    }

    // Challenge 2
    @State private var sheetType: SheetType?
    @State private var retryIncorrectCards = false
    
    static let initialTimerValue = 100
    static let maxTimerDigits = String(Self.initialTimerValue).count
    
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            Image(decorative: "background")
                .resizable()
                .scaledToFill()
                .edgesIgnoringSafeArea(.all)

            VStack {
                TimerView(timeRemaining: timeRemaining, style: .variable)
                    .font(.largeTitle)
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 5)
                    .background(
                        Capsule()
                            .fill(Color.black)
                            .opacity(0.75)
                    )

                ZStack {
                    ForEach(cards) { card in
                        CardView(card: card, retryIncorrectCards: retryIncorrectCards) { isCorrect in
                            if isCorrect {
                                self.correctCards += 1
                            } else {
                                self.incorrectCards += 1

                                if self.retryIncorrectCards {
                                    self.restackCard(at: self.index(for: card))
                                    return
                                }
                            }

                            withAnimation {
                                self.removeCard(at: self.index(for: card))
                            }
                        }
                        .stacked(at: self.index(for: card), in: self.cards.count)
                        // allow dragging only the top card
                        .allowsHitTesting(self.index(for: card) == self.cards.count - 1)
                        // let voice over read only the top card
                        .accessibility(hidden: self.index(for: card) < self.cards.count - 1)
                    }
                    .allowsHitTesting(timeRemaining > 0)
                    
                    // MARK: main UI/restart

                    // Challenge 1
                    if timeRemaining == 0 || !isActive {
                        RestartView(retryIncorrectCards: retryIncorrectCards,
                                    initialCardsCount: initialCardsCount,
                                    reviewedCards: reviewedCards,
                                    correctCards: correctCards,
                                    incorrectCards: incorrectCards,
                                    restartAction: resetCards)
                            // in comparison with the 450, 250 for each card
                            .frame(width: 300, height: 200)
                    }
                }
            }

            // MARK: settings button

            // Challenge 2
            VStack {
                HStack {
                    ActionButton(systemImage: "gear") {
                        self.showSheet(type: .settings)
                    }
                    Spacer()
                }
                Spacer()
            }
            .padding()

            // MARK: edit mode button

            VStack {
                HStack {
                    Spacer()
                    ActionButton(systemImage: "plus.circle") {
                        self.showSheet(type: .edit)
                    }
                }
                Spacer()
            }
            .padding()

            if (differentiateWithoutColor || accessibilityEnabled) && (self.timeRemaining > 0 && isActive) {
                VStack {
                    Spacer()

                    HStack {
                        Button(action: {
                            withAnimation {
                                self.removeCard(at: self.cards.count - 1)
                            }
                        }) {
                            Image(systemName: "xmark.circle")
                                .padding()
                                .background(Color.black.opacity(0.7))
                                .clipShape(Circle())
                        }
                        .accessibility(label: Text("Wrong"))
                        .accessibility(hint: Text("Mark your answer as being incorrect."))
                        Spacer()

                        Button(action: {
                            withAnimation {
                                self.removeCard(at: self.cards.count - 1)
                            }
                        }) {
                            Image(systemName: "checkmark.circle")
                                .padding()
                                .background(Color.black.opacity(0.7))
                                .clipShape(Circle())
                        }
                        .accessibility(label: Text("Correct"))
                        .accessibility(hint: Text("Mark your answer as being correct."))
                    }
                    .foregroundColor(.white)
                    .font(.largeTitle)
                    .padding()
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)) { _ in
            self.isActive = false
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            if self.cards.isEmpty == false {
                self.isActive = true
            }
        }
        .onReceive(timer) { _ in
            guard self.isActive else { return }

            if self.timeRemaining > 0 {
                self.timeRemaining -= 1

                // Challenge 1
                if self.timeRemaining == 2 {
                    self.haptics.prepare()
                } else if self.timeRemaining == 0 {
                    self.haptics.playEnding()
                }
            }
        }
        .sheet(item: $sheetType, onDismiss: resetCards) { item in
              if item == .edit {
                EditCardsView()
              } else {
                SettingsView(retryIncorrectCards: $retryIncorrectCards)
              }
        }
        .onAppear(perform: resetCards)
    }

    // Challenge 2
    private func index(for card: Card) -> Int {
        return cards.firstIndex(where: { $0.id == card.id }) ?? 0
    }

    private func showSheet(type: SheetType) {
        sheetType = type
    }

    private func restackCard(at index: Int) {
        print(index)
        guard index >= 0 else { return }

        let card = cards[index]
        cards.remove(at: index)
        cards.insert(card, at: 0)
    }

    private func removeCard(at index: Int) {
        guard index >= 0 else { return }

        cards.remove(at: index)

        // Challenge 1
        if cards.count == 1 {
            haptics.prepare()
        }

        if cards.isEmpty {
            isActive = false
            // Challenge 1
            haptics.playEnding()
        }
    }

    private func resetCards() {
        timeRemaining = Self.initialTimerValue
        isActive = true
        loadData()
    }

    private func loadData() {
        if let data = UserDefaults.standard.data(forKey: "Cards") {
            if let decoded = try? JSONDecoder().decode([Card].self, from: data) {
                cards = decoded

                // Challenge 1
                initialCardsCount = cards.count
                correctCards = 0
                incorrectCards = 0

                if cards.count == 1 {
                    haptics.prepare()
                }
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
