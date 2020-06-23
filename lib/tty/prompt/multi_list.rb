# frozen_string_literal: true

require_relative "list"
require_relative "selected_choices"

module TTY
  class Prompt
    # A class responsible for rendering multi select list menu.
    # Used by {Prompt} to display interactive choice menu.
    #
    # @api private
    class MultiList < List
      # Create instance of TTY::Prompt::MultiList menu.
      #
      # @param [Prompt] :prompt
      # @param [Hash] options
      #
      # @api public
      def initialize(prompt, **options)
        super
        @selected = SelectedChoices.new
        @help = options[:help]
        @echo = options.fetch(:echo, true)
        @min  = options[:min]
        @max  = options[:max]
      end

      # Set a minimum number of choices
      #
      # @api public
      def min(value)
        @min = value
      end

      # Set a maximum number of choices
      #
      # @api public
      def max(value)
        @max = value
      end

      # Callback fired when enter/return key is pressed
      #
      # @api private
      def keyenter(*)
        valid = true
        valid = @min <= @selected.size if @min
        valid = @selected.size <= @max if @max

        super if valid
      end
      alias keyreturn keyenter

      # Callback fired when space key is pressed
      #
      # @api private
      def keyspace(*)
        active_choice = choices[@active - 1]
        if @selected.include?(active_choice)
          @selected.delete_at(@active - 1)
        else
          return if @max && @selected.size >= @max
          @selected.insert(@active - 1, active_choice)
        end
      end

      # Selects all choices when Ctrl+A is pressed
      #
      # @api private
      def keyctrl_a(*)
        return if @max && @max < choices.size
        @selected = SelectedChoices.new(choices.enabled, choices.enabled_indexes)
      end

      # Revert currently selected choices when Ctrl+I is pressed
      #
      # @api private
      def keyctrl_r(*)
        return if @max && @max < choices.size
        indexes = choices.each_with_index.reduce([]) do |acc, (choice, idx)|
                    acc << idx if !choice.disabled? && !@selected.include?(choice)
                    acc
                  end
        @selected = SelectedChoices.new(choices.enabled - @selected.to_a, indexes)
      end

      private

      # Setup default options and active selection
      #
      # @api private
      def setup_defaults
        validate_defaults
        # At this stage, @choices matches all the visible choices.
        default_indexes = @default.map { |d| d - 1 }
        @selected = SelectedChoices.new(@choices.values_at(*default_indexes),
                                        default_indexes)

        if !@default.empty?
          @active = @default.last
        else
          @active = @choices.index { |choice| !choice.disabled? } + 1
        end
      end

      # Generate selected items names
      #
      # @return [String]
      #
      # @api private
      def selected_names
        @selected.map(&:name).join(", ")
      end

      # Header part showing the minimum/maximum number of choices
      #
      # @return [String]
      #
      # @api private
      def minmax_help
        help = []
        help << "min. #{@min}" if @min
        help << "max. #{@max}" if @max
        "(%s) " % [help.join(" ")]
      end

      # Build a default help text
      #
      # @return [String]
      #
      # @api private
      def default_help
        str = []
        str << "(Press "
        str << "#{arrows_help} arrow"
        str << " or 1-#{choices.size} number" if enumerate?
        str << " to move, Space"
        str << "/Ctrl+A|R" if @max.nil?
        str << " to select"
        str << " (all|rev)" if @max.nil?
        str << (filterable? ? "," : " and")
        str << " Enter to finish"
        str << " and letters to filter" if filterable?
        str << ")"
        str.join
      end

      # Render initial help text and then currently selected choices
      #
      # @api private
      def render_header
        instructions = @prompt.decorate(help, @help_color)
        minmax_suffix = @min || @max ? minmax_help : ""

        if @done && @echo
          @prompt.decorate(selected_names, @active_color)
        elsif @selected.size.nonzero? && @echo
          help_suffix = filterable? && @filter.any? ? " #{filter_help}" : ""
          minmax_suffix + selected_names +
            (@first_render ? " #{instructions}" : help_suffix)
        elsif @first_render
          minmax_suffix + instructions
        elsif filterable? && @filter.any?
          minmax_suffix + filter_help
        elsif @min || @max
          minmax_help
        end
      end

      # All values for the choices selected
      #
      # @return [Array[nil,Object]]
      #
      # @api private
      def answer
        @selected.map(&:value)
      end

      # Render menu with choices to select from
      #
      # @return [String]
      #
      # @api private
      def render_menu
        output = []

        sync_paginators if @paging_changed
        paginator.paginate(choices, @active, @per_page) do |choice, index|
          num = enumerate? ? (index + 1).to_s + @enum + " " : ""
          indicator = (index + 1 == @active) ?  @symbols[:marker] : " "
          indicator += " "
          message = if @selected.include?(choice) && !choice.disabled?
                      selected = @prompt.decorate(@symbols[:radio_on], @active_color)
                      "#{selected} #{num}#{choice.name}"
                    elsif choice.disabled?
                      @prompt.decorate(@symbols[:cross], :red) +
                        " #{num}#{choice.name} #{choice.disabled}"
                    else
                      "#{@symbols[:radio_off]} #{num}#{choice.name}"
                    end
          end_index = paginated? ? paginator.end_index : choices.size - 1
          newline = (index == end_index) ? "" : "\n"
          output << indicator + message + newline
        end

        output.join
      end
    end # MultiList
  end # Prompt
end # TTY
