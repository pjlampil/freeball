require "test_helper"

# Comprehensive tests for FramesController#undo.
#
# The undo action must reverse the most recent scoring action in strict
# reverse-chronological order, regardless of which visit/player it belongs to.
# Shots are ordered by (visit_number, sequence) — not sequence alone — so a
# shot in visit 2 with sequence=1 must be undone before a shot in visit 1
# with sequence=2.
class FramesUndoTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  # ─── Setup ──────────────────────────────────────────────────────────────────

  setup do
    @alice = User.create!(name: "Alice", email: "alice@example.com", password: "password")
    @bob   = User.create!(name: "Bob",   email: "bob@example.com",   password: "password")

    @match = Match.create!(
      player1: @alice, player2: @bob,
      scoring_mode: :granular, status: :in_progress, match_format: :standard
    )
    @frame = @match.frames.create!(frame_number: 1, status: :in_progress, first_to_break: @alice)
    @match.update!(current_frame: @frame)

    sign_in @alice
  end

  # ─── Helpers ────────────────────────────────────────────────────────────────

  # Create a new visit for +player+; auto-assigns the next visit_number.
  def new_visit(player)
    n = (@frame.visits.maximum(:visit_number) || 0) + 1
    @frame.visits.create!(player: player, visit_number: n)
  end

  # Pot a ball in +v+. Sequence is auto-assigned.
  def pot(v, ball)
    points = Shot::BALL_VALUES[ball.to_sym] || 0
    v.shots.create!(ball: ball, result: :potted, sequence: v.shots.count + 1, points: points)
  end

  # Record a foul in +v+ and mark the visit as ended by foul.
  # Does NOT create the next visit — tests that need one must do it explicitly.
  def foul(v, value: 4)
    v.shots.create!(ball: :red, result: :foul, foul_value: value, sequence: v.shots.count + 1, points: 0)
    v.update!(ended_by: :foul)
  end

  # End a visit as a miss without touching shots.
  def miss(v)
    v.update!(ended_by: :miss)
  end

  # Call undo and reload the frame.
  def do_undo
    post undo_frame_path(@frame)
    @frame.reload
  end

  # Ordered list of shots as "PlayerName:ball" or "PlayerName:foul(N)" strings,
  # in strict (visit_number, sequence) order.
  def shot_log
    @frame.shots
          .joins(:visit)
          .reorder("visits.visit_number ASC, shots.sequence ASC")
          .map { |s| "#{s.visit.player.name}:#{s.foul? ? "foul(#{s.foul_value})" : s.ball}" }
  end

  def current_visit
    @frame.reload.current_visit
  end

  # ─── Single-visit shots ─────────────────────────────────────────────────────

  test "undo removes the only shot" do
    v1 = new_visit(@alice)
    pot(v1, :red)

    do_undo

    assert_equal [], shot_log
    assert_equal @alice, current_visit.player
    assert current_visit.active?
  end

  test "undo removes the last shot leaving earlier shots intact" do
    v1 = new_visit(@alice)
    pot(v1, :red)
    pot(v1, :yellow)

    do_undo

    assert_equal ["Alice:red"], shot_log
    assert current_visit.active?
    assert_equal @alice, current_visit.player
  end

  test "undo removes shots in reverse sequence order within one visit" do
    v1 = new_visit(@alice)
    pot(v1, :red)
    pot(v1, :yellow)
    pot(v1, :green)

    do_undo
    assert_equal ["Alice:red", "Alice:yellow"], shot_log

    do_undo
    assert_equal ["Alice:red"], shot_log

    do_undo
    assert_equal [], shot_log
    assert current_visit.active?
  end

  test "undo with no shots is a no-op" do
    new_visit(@alice)

    do_undo

    assert_equal 0, @frame.shots.count
    assert_equal 1, @frame.visits.count
  end

  # ─── Cross-visit ordering ───────────────────────────────────────────────────
  #
  # The critical invariant: undo must remove the shot with the highest
  # (visit_number, sequence) — NOT the highest sequence alone. Shots in a
  # later visit with sequence=1 must be undone before shots in an earlier
  # visit with sequence=2.

  test "undo removes shot from later visit even when its sequence is lower" do
    # Alice: red(seq=1), miss
    # Bob:   red(seq=1)  ← same sequence, higher visit_number
    v1 = new_visit(@alice)
    pot(v1, :red)
    miss(v1)

    v2 = new_visit(@bob)
    pot(v2, :red)

    do_undo

    assert_equal ["Alice:red"], shot_log, "Undo should remove Bob's red, not Alice's"
    assert_equal @bob, current_visit.player
    assert_equal 0, current_visit.shots.count
    assert current_visit.active?
  end

  test "undo removes shot from later visit when earlier visit has more shots" do
    # Alice: red(seq=1), yellow(seq=2), miss
    # Bob:   red(seq=1)  ← lower sequence than Alice's yellow, but higher visit
    v1 = new_visit(@alice)
    pot(v1, :red)
    pot(v1, :yellow)
    miss(v1)

    v2 = new_visit(@bob)
    pot(v2, :red)

    do_undo

    assert_equal ["Alice:red", "Alice:yellow"], shot_log, "Undo should remove Bob's red, not Alice's yellow"
    assert_equal @bob, current_visit.player
    assert_equal 0, current_visit.shots.count
  end

  test "full undo sequence across two visits reverses in correct order" do
    # Sequence of actions: Alice red, Alice yellow, Alice miss,
    #                       Bob red, Bob yellow
    # Expected undo order: Bob yellow → Bob red → Alice miss →
    #                       Alice yellow → Alice red
    v1 = new_visit(@alice)
    pot(v1, :red)
    pot(v1, :yellow)
    miss(v1)

    v2 = new_visit(@bob)
    pot(v2, :red)
    pot(v2, :yellow)

    # 1. Bob yellow
    do_undo
    assert_equal ["Alice:red", "Alice:yellow", "Bob:red"], shot_log
    assert_equal @bob, current_visit.player
    assert_equal 1, current_visit.shots.count
    assert current_visit.active?

    # 2. Bob red → Bob's visit still exists but is empty
    do_undo
    assert_equal ["Alice:red", "Alice:yellow"], shot_log
    assert_equal @bob, current_visit.player
    assert_equal 0, current_visit.shots.count
    assert current_visit.active?

    # 3. Alice miss → Bob's empty visit destroyed, Alice's visit reopened
    do_undo
    assert_equal ["Alice:red", "Alice:yellow"], shot_log
    assert_equal @alice, current_visit.player
    assert current_visit.active?
    assert_equal 1, @frame.visits.count

    # 4. Alice yellow
    do_undo
    assert_equal ["Alice:red"], shot_log

    # 5. Alice red
    do_undo
    assert_equal [], shot_log
    assert current_visit.active?
  end

  test "full undo sequence across three visits reverses in correct order" do
    # Alice red, miss → Bob red, yellow, miss → Alice red
    v1 = new_visit(@alice)
    pot(v1, :red)
    miss(v1)

    v2 = new_visit(@bob)
    pot(v2, :red)
    pot(v2, :yellow)
    miss(v2)

    v3 = new_visit(@alice)
    pot(v3, :red)

    # 1. Alice red (v3)
    do_undo
    assert_equal ["Alice:red", "Bob:red", "Bob:yellow"], shot_log
    assert_equal @alice, current_visit.player
    assert_equal 0, current_visit.shots.count

    # 2. Bob miss (v3 is empty → undo miss, v3 destroyed, v2 reopened)
    do_undo
    assert_equal ["Alice:red", "Bob:red", "Bob:yellow"], shot_log
    assert_equal @bob, current_visit.player
    assert current_visit.active?
    assert_equal 2, @frame.visits.count

    # 3. Bob yellow
    do_undo
    assert_equal ["Alice:red", "Bob:red"], shot_log

    # 4. Bob red
    do_undo
    assert_equal ["Alice:red"], shot_log
    assert_equal @bob, current_visit.player
    assert_equal 0, current_visit.shots.count

    # 5. Alice miss (Bob's visit is empty → undo miss, v2 destroyed, v1 reopened)
    do_undo
    assert_equal ["Alice:red"], shot_log
    assert_equal @alice, current_visit.player
    assert current_visit.active?
    assert_equal 1, @frame.visits.count

    # 6. Alice red (v1)
    do_undo
    assert_equal [], shot_log
  end

  test "undo across four visits removes shots in strict reverse order" do
    # Actions in order: Alice red, Alice miss, Bob red, Bob miss, Alice yellow, Alice miss, Bob yellow
    # 7 actions → 7 undos to fully reverse
    v1 = new_visit(@alice); pot(v1, :red);    miss(v1)
    v2 = new_visit(@bob);   pot(v2, :red);    miss(v2)
    v3 = new_visit(@alice); pot(v3, :yellow); miss(v3)
    v4 = new_visit(@bob);   pot(v4, :yellow)

    assert_equal ["Alice:red", "Bob:red", "Alice:yellow", "Bob:yellow"], shot_log

    # 1. Undo Bob yellow (v4 had 1 shot → removed, v4 is now empty/active)
    do_undo
    assert_equal ["Alice:red", "Bob:red", "Alice:yellow"], shot_log
    assert_equal @bob, current_visit.player
    assert_equal 0, current_visit.shots.count

    # 2. Undo Alice miss: v4 empty → undo v3's miss; v4 destroyed, v3 (Alice) reopened
    #    Shots unchanged — miss undo reopens the visit but removes no shots
    do_undo
    assert_equal ["Alice:red", "Bob:red", "Alice:yellow"], shot_log
    assert_equal @alice, current_visit.player
    assert current_visit.active?
    assert_equal 3, @frame.visits.count

    # 3. Undo Alice yellow (v3 still has the yellow shot)
    do_undo
    assert_equal ["Alice:red", "Bob:red"], shot_log
    assert_equal @alice, current_visit.player
    assert_equal 0, current_visit.shots.count

    # 4. Undo Bob miss: v3 empty → undo v2's miss; v3 destroyed, v2 (Bob) reopened
    do_undo
    assert_equal ["Alice:red", "Bob:red"], shot_log
    assert_equal @bob, current_visit.player
    assert current_visit.active?
    assert_equal 2, @frame.visits.count

    # 5. Undo Bob red
    do_undo
    assert_equal ["Alice:red"], shot_log
    assert_equal @bob, current_visit.player
    assert_equal 0, current_visit.shots.count

    # 6. Undo Alice miss: v2 empty → undo v1's miss; v2 destroyed, v1 (Alice) reopened
    do_undo
    assert_equal ["Alice:red"], shot_log
    assert_equal @alice, current_visit.player
    assert_equal 1, @frame.visits.count

    # 7. Undo Alice red
    do_undo
    assert_equal [], shot_log
    assert current_visit.active?
  end

  # ─── Foul handling ──────────────────────────────────────────────────────────

  test "undo a foul removes the shot and reactivates the fouling player's visit" do
    v1 = new_visit(@alice)
    foul(v1, value: 4)
    v2 = new_visit(@bob)

    do_undo

    # The foul shot itself is destroyed, and the next visit is also destroyed
    assert_equal [], shot_log
    assert_equal @alice, current_visit.player
    assert current_visit.active?
    assert_equal 1, @frame.visits.count
  end

  test "undo a foul preserves earlier shots in the same visit" do
    v1 = new_visit(@alice)
    pot(v1, :red)
    foul(v1, value: 5)
    v2 = new_visit(@bob)

    do_undo

    # Foul shot destroyed; only the earlier red remains; visit is reactivated
    assert_equal ["Alice:red"], shot_log
    assert_equal @alice, current_visit.player
    assert current_visit.active?
  end

  test "undo a foul with value 7 uses correct value in message" do
    v1 = new_visit(@alice)
    foul(v1, value: 7)
    v2 = new_visit(@bob)

    do_undo

    assert_match "7", response.body
  end

  test "undo foul then undo prior pot restores correct state" do
    v1 = new_visit(@alice)
    pot(v1, :red)
    foul(v1, value: 4)
    v2 = new_visit(@bob)

    # Undo foul: foul shot destroyed, v2 destroyed, v1 reactivated; red remains
    do_undo
    assert_equal ["Alice:red"], shot_log
    assert_equal @alice, current_visit.player
    assert current_visit.active?
    assert_equal 1, @frame.visits.count

    # Undo red
    do_undo
    assert_equal [], shot_log
    assert current_visit.active?
  end

  test "undoing a foul does not destroy next visit if shot was not a foul" do
    # Pot a red, then miss — next visit should NOT be destroyed when undoing the red
    v1 = new_visit(@alice)
    pot(v1, :red)
    miss(v1)
    v2 = new_visit(@bob)

    do_undo  # Bob's visit is empty → undo Alice's miss (not Alice's red!)

    assert_equal ["Alice:red"], shot_log
    assert_equal @alice, current_visit.player
    assert_equal 1, @frame.visits.count
  end

  # ─── Miss / end-of-visit undo ───────────────────────────────────────────────

  test "undo miss on empty visit reopens previous visit and destroys the empty one" do
    v1 = new_visit(@alice)
    pot(v1, :red)
    miss(v1)
    v2 = new_visit(@bob)

    do_undo  # Current visit (Bob's) is empty → undo Alice's miss

    assert_equal ["Alice:red"], shot_log
    assert_equal @alice, current_visit.player
    assert current_visit.active?
    assert_equal 1, @frame.visits.count
  end

  test "undo miss message includes player name" do
    v1 = new_visit(@alice)
    miss(v1)
    new_visit(@bob)

    do_undo

    assert_match "Alice", response.body
    assert_match(/miss/i, response.body)
  end

  # ─── Pending winner ─────────────────────────────────────────────────────────

  test "undo last shot clears pending winner and reactivates the visit" do
    v1 = new_visit(@alice)
    pot(v1, :red)
    v1.update!(ended_by: :frame_end)
    @frame.update!(pending_winner: @alice)

    do_undo

    @frame.reload
    assert_nil @frame.pending_winner
    assert_equal @alice, current_visit.player
    assert current_visit.active?
    assert_equal 1, @frame.visits.count
  end

  test "undo with pending winner and multiple visits destroys later visits" do
    v1 = new_visit(@alice)
    pot(v1, :red)
    miss(v1)
    v2 = new_visit(@bob)
    pot(v2, :red)
    v2.update!(ended_by: :frame_end)
    @frame.update!(pending_winner: @bob)

    do_undo

    @frame.reload
    assert_nil @frame.pending_winner
    assert_equal @bob, current_visit.player
    assert current_visit.active?
    assert_equal 2, @frame.visits.count
  end

  # ─── Frame completion ───────────────────────────────────────────────────────

  test "undo shot that completed the frame un-completes it" do
    v1 = new_visit(@alice)
    pot(v1, :red)
    v1.update!(ended_by: :frame_end)
    @frame.update!(
      status: :completed,
      winner: @alice,
      completed_at: Time.current,
      pending_winner: @alice
    )

    do_undo

    @frame.reload
    assert @frame.in_progress?
    assert_nil @frame.winner
    assert_nil @frame.pending_winner
    assert current_visit.active?
  end

  test "undo restores match to in_progress when the match was completed" do
    v1 = new_visit(@alice)
    pot(v1, :red)
    v1.update!(ended_by: :frame_end)
    @frame.update!(status: :completed, winner: @alice, completed_at: Time.current, pending_winner: @alice)
    @match.update!(status: :completed, current_frame: nil)

    do_undo

    @frame.reload
    @match.reload
    assert @frame.in_progress?
    assert @match.in_progress?
    assert_equal @frame, @match.current_frame
  end

  test "undo destroys the auto-created next frame when undoing frame completion" do
    v1 = new_visit(@alice)
    pot(v1, :red)
    v1.update!(ended_by: :frame_end)
    @frame.update!(status: :completed, winner: @alice, completed_at: Time.current, pending_winner: @alice)

    next_frame = @match.frames.create!(frame_number: 2, status: :in_progress, first_to_break: @bob)
    @match.update!(status: :in_progress, current_frame: next_frame)

    do_undo

    @match.reload
    assert_equal @frame, @match.current_frame
    assert @match.in_progress?
    assert_raises(ActiveRecord::RecordNotFound) { next_frame.reload }
  end

  # ─── Scores after undo ──────────────────────────────────────────────────────

  test "scores are correct after undoing a potted ball" do
    v1 = new_visit(@alice)
    pot(v1, :red)
    pot(v1, :black)   # +7

    assert_equal 8, @frame.reload.player1_score

    do_undo  # undo black

    assert_equal 1, @frame.player1_score
  end

  test "scores are correct after undoing a foul" do
    v1 = new_visit(@alice)
    foul(v1, value: 6)  # Bob gains 6
    v2 = new_visit(@bob)

    assert_equal 6, @frame.reload.player2_score  # foul points go to opponent

    do_undo

    assert_equal 0, @frame.player2_score
  end

  test "scores are unaffected by undoing a miss" do
    v1 = new_visit(@alice)
    pot(v1, :red)
    miss(v1)
    v2 = new_visit(@bob)

    assert_equal 1, @frame.reload.player1_score

    do_undo  # undo miss

    assert_equal 1, @frame.player1_score
  end

  # ─── Undo message content ───────────────────────────────────────────────────

  test "undo message identifies player and ball for a potted red" do
    v1 = new_visit(@alice)
    pot(v1, :red)

    do_undo

    assert_match "Alice", response.body
    assert_match(/red/i, response.body)
  end

  test "undo message identifies player and ball for a potted black" do
    v1 = new_visit(@bob)
    pot(v1, :black)

    do_undo

    assert_match "Bob", response.body
    assert_match(/black/i, response.body)
  end

  test "undo message for foul includes player and foul value" do
    v1 = new_visit(@alice)
    foul(v1, value: 7)
    new_visit(@bob)

    do_undo

    assert_match "Alice", response.body
    assert_match "7", response.body
  end

  test "undo message for miss identifies the correct player" do
    v1 = new_visit(@bob)
    miss(v1)
    new_visit(@alice)

    do_undo

    assert_match "Bob", response.body
  end

  test "undo message shows the correct player when the last shot belongs to the second player" do
    v1 = new_visit(@alice)
    pot(v1, :red)
    miss(v1)

    v2 = new_visit(@bob)
    pot(v2, :red)

    do_undo

    assert_match "Bob", response.body
    assert_no_match(/Alice.*red/i, response.body)
  end
end
