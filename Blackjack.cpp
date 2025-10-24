#include <iostream>      // For input and output operations
#include <vector>        // For using the vector container
#include <algorithm>     // For shuffle algorithm
#include <random>        // For random number generation
#include <ctime>         // For seeding random generator with current time
#include <string>        // For using the string class

using namespace std;     // Use the standard namespace

// Card structure to represent a playing card
struct Card {
    string rank;         // Rank of the card (2-10, J, Q, K, A)
    string suit;         // Suit of the card (Hearts, Diamonds, Clubs, Spades)
};

// Function to create and shuffle a deck of cards
vector<Card> create_deck() {
    vector<string> suits = {"Hearts", "Diamonds", "Clubs", "Spades"}; // All suits
    vector<string> ranks = {"2", "3", "4", "5", "6", "7", "8", "9", "10", "J", "Q", "K", "A"}; // All ranks
    vector<Card> deck; // Vector to hold the deck
    for (const auto& suit : suits) { // Loop through suits
        for (const auto& rank : ranks) { // Loop through ranks
            deck.push_back({rank, suit}); // Add each card to the deck
        }
    }
    shuffle(deck.begin(), deck.end(), default_random_engine(static_cast<unsigned>(time(0)))); // Shuffle the deck
    return deck; // Return the shuffled deck
}

// Function to get the value of a card for blackjack
int card_value(const Card& card) {
    if (card.rank == "J" || card.rank == "Q" || card.rank == "K") return 10; // Face cards are worth 10
    if (card.rank == "A") return 11; // Ace is worth 11 (may be reduced later)
    return stoi(card.rank); // Number cards are worth their number
}

// Function to get the value of a hand, handling aces as 1 or 11
int hand_value(const vector<Card>& hand) {
    int value = 0, aces = 0; // Total value and count of aces
    for (const auto& card : hand) {
        value += card_value(card); // Add card value
        if (card.rank == "A") aces++; // Count aces
    }
    // If value is over 21, convert aces from 11 to 1 as needed
    while (value > 21 && aces) {
        value -= 10;
        aces--;
    }
    return value; // Return hand value
}

// Function to draw a single card as ASCII art
string draw_card(const Card& card) {
    string rank = card.rank;
    if (rank.length() == 1) rank += " "; // Pad single-digit ranks for alignment
    string suit_symbol;
    // Use simple suit symbols for compatibility
    if (card.suit == "Hearts") suit_symbol = "H";      // Hearts
    else if (card.suit == "Diamonds") suit_symbol = "D"; // Diamonds
    else if (card.suit == "Clubs") suit_symbol = "C";    // Clubs
    else if (card.suit == "Spades") suit_symbol = "S";   // Spades
    else suit_symbol = "?"; // Unknown suit

    // Build ASCII art for the card
    string card_art =
        "+-----+\n"
        "|" + rank + "   |\n"
        "|  " + suit_symbol + "  |\n"
        "|   " + rank + "|\n"
        "+-----+";
    return card_art; // Return ASCII art string
}

// Function to draw a hand of cards as ASCII art side by side and show score
void show_hand_graphic(const vector<Card>& hand, bool hide_first = false) {
    vector<vector<string>> card_lines; // Holds lines for each card's ASCII art
    for (size_t i = 0; i < hand.size(); ++i) {
        string art;
        // Hide the first card for dealer's initial hand
        if (hide_first && i == 0) {
            art =
                "+-----+\n"
                "|#####|\n"
                "|#####|\n"
                "|#####|\n"
                "+-----+";
        } else {
            art = draw_card(hand[i]); // Draw actual card
        }
        // Split ASCII art into lines
        vector<string> lines;
        size_t start = 0, end;
        for (int l = 0; l < 5; ++l) {
            end = art.find('\n', start);
            if (end == string::npos) end = art.length();
            lines.push_back(art.substr(start, end - start));
            start = end + 1;
        }
        card_lines.push_back(lines); // Add lines for this card
    }
    // Print all cards side by side
    for (int row = 0; row < 5; ++row) {
        for (size_t col = 0; col < card_lines.size(); ++col) {
            cout << card_lines[col][row] << " ";
        }
        cout << endl;
    }
    // Show score (hide dealer's score if first card is hidden)
    if (hide_first) {
        cout << "Score: ??" << endl;
    } else {
        cout << "Score: " << hand_value(hand) << endl;
    }
}

// Main blackjack game loop
void blackjack_game() {
    int money = 100; // Start with $100

    while (money > 0) { // Continue playing until money runs out
        cout << "\nYou have $" << money << ". Enter your bet: "; // Show current money and ask for bet
        int bet;
        string input;
        while (true) { // Validate bet input
            cin >> input;
            // Check if input is numeric
            bool is_numeric = true;
            for (char c : input) {
                if (!isdigit(c)) {
                    is_numeric = false;
                    break;
                }
            }
            if (is_numeric) {
                bet = stoi(input);
                if (bet > 0 && bet <= money) break;
            }
            cout << "Invalid bet. Please enter a number between 1 and " << money << ": ";
        }

        auto deck = create_deck(); // Create and shuffle deck
        // Deal two cards to player and dealer
        vector<Card> player_hand = {deck.back()}; deck.pop_back();
        player_hand.push_back(deck.back()); deck.pop_back();
        vector<Card> dealer_hand = {deck.back()}; deck.pop_back();
        dealer_hand.push_back(deck.back()); deck.pop_back();

        cout << "\nYour hand:" << endl;
        show_hand_graphic(player_hand); // Show player's hand and score
        cout << "\nDealer's hand:" << endl;
        show_hand_graphic(dealer_hand, true); // Show dealer's hand with first card hidden

        bool player_bust = false;      // Track if player busts
        bool player_blackjack = false; // Track if player gets blackjack
        while (true) { // Player's turn
            if (hand_value(player_hand) == 21) { // Check for blackjack
                cout << "Blackjack! You win!" << endl;
                player_blackjack = true;
                break;
            }
            cout << "Hit or Stand? (h/s): "; // Ask player for action
            string move;
            cin >> move;
            if (move == "h") { // Player chooses to hit
                player_hand.push_back(deck.back()); deck.pop_back(); // Deal another card
                cout << "\nYour hand:" << endl;
                show_hand_graphic(player_hand); // Show updated hand
                if (hand_value(player_hand) > 21) { // Check for bust
                    cout << "Bust! You lose." << endl;
                    player_bust = true;
                    break;
                }
            } else if (move == "s") { // Player stands
                break;
            }
        }

        cout << "\nDealer's hand:" << endl;
        show_hand_graphic(dealer_hand); // Reveal dealer's hand and score
        // Dealer's turn: hit until value is at least 17
        while (!player_bust && hand_value(dealer_hand) < 17) {
            dealer_hand.push_back(deck.back()); deck.pop_back();
            cout << "Dealer hits:" << endl;
            show_hand_graphic(dealer_hand); // Show dealer's updated hand
        }

        int player_score = hand_value(player_hand); // Final player score
        int dealer_score = hand_value(dealer_hand); // Final dealer score
        cout << "Your score: " << player_score << endl;
        cout << "Dealer's score: " << dealer_score << endl;

        // Determine outcome and update money
        if (player_bust) {
            money -= bet;
            cout << "You lost $" << bet << "." << endl;
        } else if (player_blackjack) {
            money += static_cast<int>(bet * 1.5); // Blackjack pays 3:2
            cout << "You won $" << static_cast<int>(bet * 1.5) << "!" << endl;
        } else if (dealer_score > 21 || player_score > dealer_score) {
            money += bet;
            cout << "You won $" << bet << "!" << endl;
        } else if (player_score < dealer_score) {
            money -= bet;
            cout << "You lost $" << bet << "." << endl;
        } else {
            cout << "Push (tie). Your bet is returned." << endl;
        }
    }

    cout << "\nYou are out of money! Game over." << endl; // End game message
}

// Program entry point
int main() 
{
    blackjack_game(); // Start the blackjack game
    return 0;         // End program
}