import random, time
from blackjack_pkg import interface, card_conversion

deck = []
next_card = ""

def start():
    print("tae")
    card_conversion.clearConsole()
    suits = ["Hearts", "Spades", "Diamonds", "Clubs"]
    ranks = list(card_conversion.rank_dictionary.keys())
    
    for suit in suits:
        for rank in ranks:
            deck.append(f'{rank} of {suit}')

    random.shuffle(deck)
    option()

def option():
    if len(deck) < 4:
        quit_game() 
    else:
        player_init_cards = [deck[index] for index in [0, 2]]
        computer_init_cards = [deck[index] for index in [1, 3]]
        card_conversion.clearConsole()
        print(f"\nPlayer's cards are {player_init_cards[0]} and {player_init_cards[1]}")
        for x in range(4):
            deck.pop(0)# remove first 4 cards on start of each round
        interface.intro()
        while True:
            number = input(f"Choose an option: ")
            if len(deck) == 0:
                quit_game()

            if number == '1': # Ask for another card
                if len(deck) == 0:
                    quit_game()
                else:
                    card_conversion.clearConsole()
                    next_card = card_conversion.next_card(deck)
                    player_init_cards.append(next_card)
                    end_game(computer_init_cards, player_init_cards)

            elif number == '2': # compare cards
                hold_cards(computer_init_cards, player_init_cards)

            elif number == '3':# Check all open card
                card_conversion.clearConsole()
                interface.intro()
                card_conversion.player_cards(player_init_cards)
                print(f"Dealer's card is {computer_init_cards[0]}")

            elif number == '4': # exit
                print("\nLeaving the table...")
                exit()
            print("Invalid option")

def play_again():
    number = input("Type Q to quit the game: ")
    if number.lower() == ("Q").lower():
        print("\nLeaving the table...")
        exit()
        
    card_conversion.clearConsole()
    option()

def hold_cards(computer_init_cards, player_init_cards):
    while len(deck) != 0:
        a = (card_conversion.int_computer_cards(computer_init_cards))
        b = (card_conversion.int_player_cards(player_init_cards))
        if a == b:
            print("It's a draw!")
            play_again()

        if a > b and a < 21:
            card_conversion.player_cards(player_init_cards)
            card_conversion.computer_cards(computer_init_cards)
            print("Dealer wins!")
            play_again()

        if a < b and a < 21:
            if len(deck) == 0:
                quit_game()
            else:
                card_conversion.computer_cards(computer_init_cards)
                time.sleep(3)
                print("\nDealer picks another card")
                time.sleep(3)
                next_card = card_conversion.next_card(deck)
                computer_init_cards.append(next_card)
                time.sleep(4)
        if a == 21:
            print("Blackjack! Dealer wins!")
            play_again()
        if b > 21:
            print("Bust! Player wins!")
            play_again()
        quit_game()

def end_game(computer_init_cards, player_init_cards):
    interface.intro()
    if card_conversion.int_player_cards(player_init_cards) > 21:
        print("Bust! Dealer wins")
        play_again()

    if card_conversion.int_player_cards(player_init_cards) == 21:
        print("You got 21... lets check Dealer's cards")
        hold_cards(computer_init_cards, player_init_cards)

    else:
        return 

def quit_game():
    print("No cards left. Do you want to play again?")
    number = input("Type Q to quit the game: ")
    if number.lower() == ("Q").lower():
        print("\nLeaving the table...")
        exit()
        
    else:
        card_conversion.clearConsole()
        start()

start()


