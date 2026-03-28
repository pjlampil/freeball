module ApplicationHelper
  def match_status_badge(match)
    case match.status
    when "pending"   then "bg-gray-700 text-gray-300"
    when "in_progress" then "bg-green-900 text-green-300"
    when "completed" then "bg-blue-900 text-blue-300"
    end
  end

  def ball_dot_color(ball)
    case ball
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
end
