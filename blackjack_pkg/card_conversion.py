import os
rank_dictionary = {'Ace': 1, 'Two': 2, 'Three': 3, 'Four': 4, 'Five': 5, 'Six': 6, 'Seven': 7, 'Eight': 8, 'Nine': 9, 'Ten': 10, 'Jack': 10, 'Queen': 10, 'King': 10}

def next_card(deck):
    next_card = deck[0]
    print(f"\nCard Drawn is {next_card}")
    return deck.pop(0)

def int_player_cards(player_init_cards):
    player_cards_list = ""
    player_cards_list_i = 0
    substring_list = []
    sum = 0
    
    while player_cards_list_i < len(player_init_cards):
        player_cards_list = player_init_cards[player_cards_list_i]
        tup = player_cards_list[0:] #
        split_string = tup.split(" of ", 1)# to isolate the rank on string
        substring = split_string[0]
        substring_list.insert(0, "".join(list(substring)))
        player_cards_list_i = player_cards_list_i + 1
        i = 0
        while i < len(substring_list) :# use rank as key, then we use the value of the key as score
            sum += rank_dictionary[substring_list[i]]
            break
    return sum

def int_computer_cards(computer_init_cards):
    computer_cards_list = ""
    computer_cards_list_i = 0
    substring_list = []
    sum = 0
    
    while computer_cards_list_i < len(computer_init_cards):
        computer_cards_list = computer_init_cards[computer_cards_list_i]
        tup = computer_cards_list[0:] #
        split_string = tup.split(" of ", 1)# to isolate the rank on string
        substring = split_string[0]
        substring_list.insert(0, "".join(list(substring)))
        computer_cards_list_i = computer_cards_list_i + 1
        i = 0
        while i < len(substring_list) :# use rank as key, then we use the value of the key as score
            sum += rank_dictionary[substring_list[i]]
            break
    return sum

def computer_cards(computer_init_cards):
    j = len(computer_init_cards)
    print("Dealer's cards are", ", ".join(computer_init_cards[0:j-1]), "and", computer_init_cards[j-1])# range index and join method

def player_cards(player_init_cards):
    i = len(player_init_cards)
    print("\nPlayer's cards are", ", ".join(player_init_cards[0:i-1]), "and", player_init_cards[i-1])# range index and join method

def clearConsole():
    command = 'clear'
    if os.name in ('nt', 'dos'):  
        command = 'cls'
    os.system(command)

