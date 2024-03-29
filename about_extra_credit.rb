# EXTRA CREDIT:
#
# Create a program that will play the Greed Game.
# Rules for the game are in GREED_RULES.TXT.
#
# You already have a DiceSet class and score function you can use.
# Write a player class and a Game class to complete the project.  This
# is a free form assignment, so approach it however you desire.

class Player
  attr_reader :id
  attr_accessor :in_game
  attr_accessor :final_turn_played
  attr_accessor :score
  def initialize(id)
    @id = id
    @score = 0
  end
end

class Game
  class GameStartError < RuntimeError
  end
  class GamePlayError < RuntimeError
  end
  class GameEndError < RuntimeError
  end

  attr_reader :turn_score

  def initialize(*players)
    raise GameStartError, "Not enough players" if players.size < 2
    raise GameStartError, "Players must have unique names" if players.
      map { |player| player.id }.uniq.size != players.size
    @players = players
    @current_player = players[0]
    @dice_allowed = 5
    @turn_score = 0
  end

  def roll(dice_roll)
    raise GamePlayError, "Must roll with #{@dice_allowed} die" if dice_roll.size != @dice_allowed
    raise GameEndError, "Game has ended" if @final_round && @current_player.final_turn_played
    @rolled = true
    score = score(dice_roll)
    if score == 0
      setup_next_player_turn
      return 0
    end

    @turn_score += score
    @dice_allowed = dice_roll.filter { |side| side != 1 && side != 5 }.
      group_by { |side| side }.
      inject(0) { |dice_allowed, side| dice_allowed + side[1].size % 3 }
    @dice_allowed = 5 if @dice_allowed == 0
    @dice_allowed
  end

  def end_turn
    raise GamePlayError, "Cannot end turn until you roll" unless @rolled
    raise GamePlayError, "Cannot end turn until player is in" if @turn_score < 300 && !@current_player.in_game
    @current_player.in_game = true
    @current_player.score += @turn_score
    final_round_triggered = @current_player.score >= 3000
    setup_next_player_turn
    @final_round = true if final_round_triggered
  end

  private def setup_next_player_turn
    @dice_allowed = 5
    @turn_score = 0
    @rolled = false
    @current_player.final_turn_played = true if @final_round
    next_player_index = @players.find_index { |player| player.id == @current_player.id } + 1
    next_player_index = 0 if next_player_index == @players.size
    @current_player = @players[next_player_index]
  end
end

class GreedGameTests < Neo::Koan
  def setup
    @player1 = Player.new :player1
    @player2 = Player.new :player2
    @game = Game.new @player1, @player2
  end

  def test_less_than_2_players_raises_error
    ex = assert_raise(Game::GameStartError) do
      Game.new Player.new :player
    end
    assert_equal "Not enough players", ex.message
  end

  def test_players_must_have_unique_names
    player1 = Player.new :player
    player2 = Player.new :player
    ex = assert_raise(Game::GameStartError) do
      Game.new player1, player2
    end
    assert_equal "Players must have unique names", ex.message
  end

  def test_must_roll_5_die
    ex = assert_raise(Game::GamePlayError) do
      @game.roll([1, 2, 3, 4])
    end
    assert_equal "Must roll with 5 die", ex.message
  end

  def test_player_can_check_turn_score
    @game.roll([5, 1, 3, 4, 1])
    assert_equal 250, @game.turn_score
  end

  def test_roll_returns_number_of_die_to_re_roll_with
    assert_equal 2, @game.roll([5, 1, 3, 4, 1])
  end

  def test_player_re_rolls_with_all_die_if_all_scored
    assert_equal 5, @game.roll([5, 2, 1, 2, 2])
  end

  def test_player_can_only_re_roll_with_non_scoring_die
    @game.roll([5, 1, 3, 4, 1])
    ex = assert_raise(Game::GamePlayError) do
      @game.roll([5, 1, 3, 4, 1])
    end
    assert_equal "Must roll with 2 die", ex.message
  end

  def test_subsequent_rolls_add_to_turn_score
    @game.roll([5, 1, 3, 4, 1])
    @game.roll([1, 5])
    assert_equal 400, @game.turn_score
  end

  def test_player_accumulates_turn_score_if_they_end_their_turn
    @game.roll([5, 1, 3, 4, 1])
    @game.roll([1, 5])
    @game.end_turn
    assert_equal 400, @player1.score
  end

  def test_turn_ends_when_no_dice_left_to_roll
    @game.roll([5, 1, 3, 4, 1])
    assert_equal 0, @game.roll([3, 4])
  end

  def test_player_loses_turn_score_if_first_roll_scores_zero
    @game.roll([2, 3, 3, 4, 6])
    assert_equal 0, @player1.score
    @game.roll([5, 1, 1, 4, 1])
    @game.end_turn
    assert_equal 1050, @player2.score
  end

  def test_player_loses_turn_score_if_subsequent_roll_scores_zero
    @game.roll([5, 1, 3, 4, 1])
    @game.roll([3, 4])
    assert_equal 0, @player1.score
  end

  def test_cannot_end_turn_until_you_roll
    ex = assert_raise(Game::GamePlayError) do
      @game.end_turn
    end
    assert_equal "Cannot end turn until you roll", ex.message
  end

  def test_subsequent_players_cannot_end_turn_until_they_roll
    @game.roll([5, 1, 1, 4, 1])
    @game.end_turn
    ex = assert_raise(Game::GamePlayError) do
      @game.end_turn
    end
    assert_equal "Cannot end turn until you roll", ex.message
  end

  def test_next_player_goes_once_first_players_turn_ends
    @game.roll([5, 1, 1, 4, 1])
    @game.end_turn
    @game.roll([1, 1, 1, 3, 1])
    assert_equal 1100, @game.turn_score
    @game.end_turn
    assert_equal 1100, @player2.score
  end

  def test_first_player_goes_again_after_other_players
    @game.roll([5, 1, 1, 4, 1])
    @game.end_turn
    @game.roll([1, 1, 1, 3, 1])
    @game.end_turn
    @game.roll([2, 4, 4, 5, 4])
    @game.end_turn
    assert_equal 1500, @player1.score
  end

  def test_cannot_end_turn_until_player_is_in
    @game.roll([5, 1, 3, 4, 1])
    ex = assert_raise(Game::GamePlayError) do
      @game.end_turn
    end
    assert_equal "Cannot end turn until player is in", ex.message
  end

  def test_player_can_end_turn_with_less_than_300_once_in
    @game.roll([5, 1, 1, 4, 1])
    @game.end_turn
    @game.roll([1, 1, 1, 3, 1])
    @game.end_turn
    @game.roll([5, 1, 3, 4, 1])
    @game.end_turn
    assert_equal 1300, @player1.score
  end

  def test_game_ends_after_final_round
    @game.roll([1, 1, 1, 1, 1])
    @game.roll([1, 1, 1, 1, 1])
    @game.roll([1, 1, 1, 1, 1])
    @game.end_turn
    assert_equal 3600, @player1.score
    @game.roll([2, 3, 4, 6, 2])
    @game.roll([2, 3, 4, 6, 2])
    ex = assert_raise(Game::GameEndError) do
      @game.roll([2, 3, 4, 6, 2])
    end
    assert_equal "Game has ended", ex.message
  end

  def test_players_can_roll_multiple_times_in_final_round
    @game.roll([1, 1, 1, 1, 1])
    @game.roll([1, 1, 1, 1, 1])
    @game.roll([1, 1, 1, 1, 1])
    @game.end_turn
    @game.roll([1, 1, 1, 1, 1])
    @game.roll([1, 1, 1, 1, 1])
    @game.roll([1, 1, 1, 1, 1])
    @game.roll([1, 2, 3, 4, 6])
    @game.end_turn
    assert_equal 3700, @player2.score
    @game.roll([2, 3, 4, 5, 6])
    @game.roll([2, 3, 4, 6])
    assert_equal 3600, @player1.score
  end
end