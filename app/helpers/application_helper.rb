module ApplicationHelper
  def bootstrap_class_for(flash_type)
    {
      success: "bg-green-500",
      error: "bg-red-500",
      alert: "bg-orange-500",
      notice: "bg-blue-400"
    }.stringify_keys[flash_type.to_s] || flash_type.to_s
  end
end
