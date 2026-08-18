# frozen_string_literal: true

module Shadcn
  module Concerns
    # The hidden input that carries a control's value into the form, for the
    # three families whose value is a single scalar: Select, RadioGroup and
    # ToggleGroup.
    #
    # That input is **ours** — Radix bubbles a native control instead, and
    # nothing upstream describes it. Which is precisely why it needed an opening:
    # a host cannot address something the library invented and keeps to itself.
    #
    # `input_attributes:` is that opening. It reaches the input and nothing else:
    #
    #   Shadcn::Select::Component.new(
    #     name: "post[author_id]",
    #     input_attributes: { id: "author-id", form: "other-form" }
    #   )
    #
    # Found by installing the gem in an application that wires one select to
    # another: choosing a client reloads that client's sites. The obvious way to
    # do it is a Stimulus controller on the element whose `.value` is the
    # selection and which fires `change` — the hidden input, and there was no way
    # to name it. Attaching to the root works and is what that host settled on,
    # but two things have no such workaround: `id`, which a `<label for>` or any
    # external script needs, and `form`, which is how HTML lets a control submit
    # with a form it does not sit inside.
    #
    # ## Why only the single-valued families
    #
    # Combobox in `multiple` mode, Slider with several thumbs and Calendar in
    # `range` or `multiple` mode all render *several* hidden inputs. There is no
    # single element there to be "the control's value", and copying a caller's
    # attributes onto each is wrong in both of the ways that matter: `id` would
    # be duplicated, which is invalid, and `data-controller` would connect the
    # same controller once per input.
    #
    # Those families take their attributes on the root instead, which reaches
    # them through `**attributes` and — since 0.2.1 — concatenates
    # `data-controller` with the component's own rather than replacing it.
    #
    # ## Why the target is passed in rather than derived
    #
    # Each including component writes its own `data-shadcn--…-target` literally,
    # even though the concern could work it out from the class name.
    # `stimulus_contract_spec` finds targets by reading those literals out of the
    # source; a derived one would be invisible to it, and the check that every
    # target a component names exists in the JavaScript would quietly stop
    # covering this input.
    module SubmitsValue
      def self.included(base)
        base.class_eval do
          attr_reader :input_attributes
        end
      end

      def initialize(input_attributes: {}, **attributes)
        @input_attributes = input_attributes || {}
        super(**attributes)
      end

      private

      # A caller cannot detach the input from the control it belongs to: `name`
      # and `value` are asserted again after their attributes are merged in.
      # Everything else is theirs, including the Stimulus target — unusual to
      # replace, but it is their component to break.
      #
      # The re-assertion does not move those two keys. `Hash#merge` on a key that
      # is already present updates the value and keeps its insertion position, so
      # the attribute order the components emitted before this concern existed is
      # unchanged — which is what keeps every rendered snapshot byte-identical.
      def hidden_input_attributes(**defaults)
        { "type" => "hidden", "name" => name, "value" => value }
          .merge(defaults.transform_keys(&:to_s))
          .merge(input_attributes.transform_keys(&:to_s))
          .merge("name" => name, "value" => value)
      end
    end
  end
end
