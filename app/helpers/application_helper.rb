module ApplicationHelper
  def format_duration(seconds)
    return "—" if seconds.nil?
    m, s = seconds.divmod(60)
    "#{m}:#{s.to_s.rjust(2, '0')}"
  end

  def match_status_badge(match)
    case match.status
    when "pending"     then "bg-gray-700 text-gray-300"
    when "in_progress" then "bg-green-900 text-green-300"
    when "completed"   then "bg-blue-900 text-blue-300"
    end
  end

  def ball_dot_color(ball)
    case ball.to_s
    when "red"       then "bg-red-600 text-white"
    when "yellow"    then "bg-yellow-400 text-gray-900"
    when "green"     then "bg-green-600 text-white"
    when "brown"     then "bg-amber-700 text-white"
    when "blue"      then "bg-blue-600 text-white"
    when "pink"      then "bg-pink-500 text-white"
    when "black"     then "bg-gray-800 text-white border border-gray-600"
    when "free_ball" then "bg-purple-600 text-white"
    else                  "bg-gray-600 text-white"
    end
  end

  # CSS radial gradient that gives each ball a 3-D sphere appearance
  def ball_gradient(ball)
    case ball.to_s
    when "red"       then "radial-gradient(circle at 35% 30%, #ff7f7f, #cc0000, #6b0000)"
    when "yellow"    then "radial-gradient(circle at 35% 30%, #fff59d, #f9ca24, #a67c00)"
    when "green"     then "radial-gradient(circle at 35% 30%, #69e06e, #2ecc40, #145218)"
    when "brown"     then "radial-gradient(circle at 35% 30%, #c48556, #7c3a10, #3e1a06)"
    when "blue"      then "radial-gradient(circle at 35% 30%, #7ec8e3, #2980b9, #0d3d66)"
    when "pink"      then "radial-gradient(circle at 35% 30%, #ffb3d9, #e91e8c, #7a0044)"
    when "black"     then "radial-gradient(circle at 35% 30%, #777777, #2a2a2a, #000000)"
    when "free_ball" then "radial-gradient(circle at 35% 30%, #d4b0f7, #9b59b6, #4a1c75)"
    else                  "radial-gradient(circle at 35% 30%, #999, #555, #222)"
    end
  end

  # Glow colour for the enabled ball (box-shadow)
  def ball_glow(ball)
    case ball.to_s
    when "red"       then "0 0 14px 3px rgba(204,0,0,0.55)"
    when "yellow"    then "0 0 14px 3px rgba(249,202,36,0.55)"
    when "green"     then "0 0 14px 3px rgba(46,204,64,0.55)"
    when "brown"     then "0 0 14px 3px rgba(124,58,16,0.55)"
    when "blue"      then "0 0 14px 3px rgba(41,128,185,0.55)"
    when "pink"      then "0 0 14px 3px rgba(233,30,140,0.55)"
    when "black"     then "0 0 14px 3px rgba(80,80,80,0.55)"
    when "free_ball" then "0 0 14px 3px rgba(155,89,182,0.55)"
    else                  "none"
    end
  end
end
