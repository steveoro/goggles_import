# frozen_string_literal: true

#
# = FinDecorator
#
# - Goggles framework vers.:  6.404
# - author: Steve A.
#
# Decorator class for FinController.
#
class FinDecorator < Draper::Decorator

  delegate_all

  # Define presentation-specific methods here. Helpers are accessed through
  # `helpers` (aka `h`). You can override attributes, for example:
  #
  #   def created_at
  #     helpers.content_tag :span, class: 'time' do
  #       object.created_at.strftime("%a %m/%d/%y")
  #     end
  #   end

end
