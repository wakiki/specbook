# frozen_string_literal: true

# Screenshot recorder for spec presentations.
# Enable with: RECORD_SPECS=1 bundle exec rspec spec/system/
#
# Captures screenshots after Capybara actions AND assertions,
# with element bounding boxes for overlay highlights in the player.
# Works with both Selenium and Playwright drivers.

if ENV["RECORD_SPECS"]
  require "fileutils"

  module Specbook
    module Recorders
      module Screenshot
        SCREENSHOT_BASE = Rails.root.join("tmp/spec_screenshots")
        RUN_TIMESTAMP = Time.now.strftime("%Y%m%d_%H%M%S")
        SCREENSHOT_DIR = SCREENSHOT_BASE.join(RUN_TIMESTAMP)
        MAX_RUNS = 20

        mattr_accessor :current_example_name, :current_steps, :manifest, :step_counter,
                       :pending_assertions, :current_page, :current_gherkin_idx

        self.manifest = []
        self.step_counter = 0
        self.current_gherkin_idx = -1

        def self.reset_for_example!(example, page)
          self.current_example_name = example.full_description
          self.current_steps = []
          self.step_counter = 0
          self.pending_assertions = []
          self.current_page = page
          self.current_gherkin_idx = -1
          self.step_sources = {}
        end

        mattr_accessor :step_sources
        self.step_sources = {}

        def self.advance_gherkin_step!
          self.current_gherkin_idx += 1
        end

        # Record step definition source code, keyed by gherkin index
        def self.record_step_source!(file, line, body)
          step_sources[current_gherkin_idx] = { file: file, line: line, body: body }
        end

        def self.capture!(page, description, target_element: nil, action_type: "navigate")
          return unless current_example_name

          # Flush any pending assertions before a new action
          flush_assertions!(page) if pending_assertions.present? && action_type != "assert"

          self.step_counter += 1
          filename = "step_#{manifest.size.to_s.rjust(4, '0')}_#{step_counter.to_s.rjust(3, '0')}.png"
          filepath = SCREENSHOT_DIR.join(filename)

          begin
            bbox = target_element ? get_bounding_box(page, target_element) : nil
            bbox = nil if bbox.is_a?(Hash) && (bbox.empty? || bbox["x"].nil?)
            page.save_screenshot(filepath)
            step_data = {
              file: filename,
              description: description,
              url: page.current_url,
              action: action_type,
              bbox: bbox
            }.compact
            step_data[:gi] = current_gherkin_idx if current_gherkin_idx >= 0
            current_steps << step_data
          rescue StandardError
            # Skip if screenshot fails
          end
        end

        def self.record_assertion!(description, elements: [], bboxes: nil, negative: false)
          return unless current_example_name

          if bboxes.nil?
            page = current_page
            bboxes = elements.filter_map { |el| get_bounding_box(page, el) }
          end

          pending_assertions << {
            description: description,
            bboxes: bboxes || [],
            negative: negative
          }
        end

        def self.flush_assertions!(page)
          return unless current_example_name
          return if pending_assertions.blank?

          self.step_counter += 1
          filename = "step_#{manifest.size.to_s.rjust(4, '0')}_#{step_counter.to_s.rjust(3, '0')}.png"
          filepath = SCREENSHOT_DIR.join(filename)

          begin
            page.save_screenshot(filepath)

            descriptions = pending_assertions.map do |a|
              prefix = a[:negative] ? "✗ NOT: " : "✓ "
              "#{prefix}#{a[:description]}"
            end

            all_bboxes = pending_assertions.flat_map { |a| a[:bboxes] }

            step_data = {
              file: filename,
              description: descriptions.join(" | "),
              url: page.current_url,
              action: "assert",
              assertions: pending_assertions.map { |a|
                {
                  text: (a[:negative] ? "NOT: " : "") + a[:description],
                  bboxes: a[:bboxes],
                  negative: a[:negative]
                }
              }
            }.compact
            step_data[:gi] = current_gherkin_idx if current_gherkin_idx >= 0
            current_steps << step_data
          rescue StandardError
            # Skip
          end

          self.pending_assertions = []
        end

        def self.get_bounding_box(page, element)
          return nil unless element.respond_to?(:native)

          page.evaluate_script(<<~JS, element)
            (function(el) {
              if (!el) return null;
              if (!el.offsetParent && getComputedStyle(el).position !== 'fixed' && getComputedStyle(el).position !== 'sticky') return null;
              var s = getComputedStyle(el);
              if (s.display === 'none' || s.visibility === 'hidden' || s.opacity === '0') return null;
              el.scrollIntoView({ block: 'center', behavior: 'instant' });
              var rect = el.getBoundingClientRect();
              var vw = document.documentElement.clientWidth || window.innerWidth;
              var vh = document.documentElement.clientHeight || window.innerHeight;
              if (rect.width <= 0 || rect.height <= 0) return null;
              if (rect.right <= 0 || rect.bottom <= 0 || rect.x >= vw || rect.y >= vh) return null;
              var x = Math.max(0, rect.x), y = Math.max(0, rect.y);
              var w = Math.min(vw, rect.right) - x, h = Math.min(vh, rect.bottom) - y;
              if (w <= 2 || h <= 2) return null;
              return { x: Math.round(x), y: Math.round(y), width: Math.round(w), height: Math.round(h) };
            })(arguments[0])
          JS
        rescue StandardError
          nil
        end

        def self.finalize_example!(example)
          # Allow Turnip features through even without screenshots (service/model specs)
          return if current_steps.blank? && !example.metadata[:turnip]

          # Extract describe/context group hierarchy for sidebar grouping
          groups = []
          eg = example.example_group
          while eg
            groups.unshift(eg.description) if eg.description.present?
            eg = eg.superclass
            break if eg == ::RSpec::Core::ExampleGroup || !eg.respond_to?(:description)
          end

          # For Turnip features, use the scenario name (last group) instead of the step chain
          desc = if example.metadata[:turnip] && groups.length >= 2
                   groups.last
                 else
                   example.description
                 end

          entry = {
            name: current_example_name,
            description: desc,
            groups: groups,
            file: example.metadata[:file_path].sub("./", ""),
            line: example.metadata[:line_number],
            type: example.metadata[:adversarial] ? "adversarial" : "happy",
            status: example.exception ? "failed" : "passed",
            steps: current_steps.dup
          }

          # For Turnip features, embed the Gherkin steps + step sources for the sidebar
          if example.metadata[:turnip]
            gherkin = extract_gherkin(example.metadata[:file_path], desc)
            if gherkin && step_sources.present?
              bg_len = (gherkin[:background] || []).length
              (gherkin[:background] || []).each_with_index do |s, i|
                s[:source] = step_sources[i] if step_sources[i]
              end
              (gherkin[:scenario] || []).each_with_index do |s, i|
                s[:source] = step_sources[bg_len + i] if step_sources[bg_len + i]
              end
            end
            entry[:gherkin] = gherkin
          end
          self.step_sources = {}

          manifest << entry
          self.current_steps = []
        end

        def self.extract_gherkin(file_path, scenario_name)
          path = file_path.start_with?("./") ? file_path[2..] : file_path
          full_path = Rails.root.join(path)
          return nil unless File.exist?(full_path)

          content = File.read(full_path)
          result = { background: [], scenario: [] }
          current = nil

          content.each_line do |line|
            stripped = line.rstrip
            if stripped =~ /^\s*Background:/
              current = :background
            elsif stripped =~ /^\s*Scenario:\s*(.+)/
              if $1.strip == scenario_name
                current = :scenario
              elsif current == :scenario
                break # Hit next scenario, done
              else
                current = nil
              end
            elsif current && stripped =~ /^\s+(Given|And|When|Then)\s+(.+)/
              result[current] << { keyword: $1, text: $2.strip }
            end
          end
          result
        rescue StandardError
          nil
        end

        def self.write_manifest!
          FileUtils.mkdir_p(SCREENSHOT_DIR)
          File.write(
            SCREENSHOT_DIR.join("manifest.json"),
            JSON.pretty_generate(manifest)
          )
        end
      end
    end
  end

  # Patch Capybara actions to capture screenshots with element tracking
  module Specbook
    module Recorders
      module CapybaraScreenshotPatch
        def visit(path, **)
          # Flush pending assertions BEFORE navigating (while old page is still visible)
          Specbook::Recorders::Screenshot.flush_assertions!(page) if Specbook::Recorders::Screenshot.pending_assertions.present?
          super.tap { Specbook::Recorders::Screenshot.capture!(page, "Navigate to #{path}", action_type: "navigate") }
        end

        def click_on(locator = nil, **opts)
          el = _find_target_element(locator, opts)
          # Capture BEFORE click — shows what was clicked, not the post-click state
          Specbook::Recorders::Screenshot.capture!(page, "Click '#{locator || opts[:text] || 'element'}'", target_element: el, action_type: "click")
          super
        end

        def click_link(locator = nil, **opts)
          el = begin
            if opts[:href]
              find(:link, href: opts[:href], wait: 0)
            else
              find_link(locator || opts[:text], wait: 0)
            end
          rescue Capybara::ElementNotFound, Capybara::Ambiguous
            nil
          end
          Specbook::Recorders::Screenshot.capture!(page, "Click link '#{locator || opts[:text] || opts[:href]}'", target_element: el, action_type: "click")
          super
        end

        def click_button(locator = nil, **opts)
          # Find element for bbox before clicking
          el = begin
            find_button(locator || opts[:text], wait: 0)
          rescue Capybara::ElementNotFound, Capybara::Ambiguous
            begin; find(:css, "button", text: locator || opts[:text], wait: 0); rescue; nil; end
          end
          Specbook::Recorders::Screenshot.capture!(page, "Click button '#{locator || opts[:text]}'", target_element: el, action_type: "click")
          super
        end

        def fill_in(locator = nil, with:, **opts)
          el = begin; find_field(locator || opts[:id] || opts[:name]); rescue Capybara::ElementNotFound; nil; end
          super.tap { Specbook::Recorders::Screenshot.capture!(page, "Type '#{with.to_s.truncate(30)}' into '#{locator}'", target_element: el, action_type: "fill") }
        end

        def select(value = nil, from: nil, **opts)
          el = begin; find_field(from); rescue Capybara::ElementNotFound; nil; end
          super.tap { Specbook::Recorders::Screenshot.capture!(page, "Select '#{value}' from '#{from}'", target_element: el, action_type: "select") }
        end

        def choose(locator = nil, **opts)
          el = begin
            find(:radio_button, locator)
          rescue Capybara::ElementNotFound, Capybara::Ambiguous
            begin; find(:css, "label", text: locator); rescue; nil; end
          end
          super.tap { Specbook::Recorders::Screenshot.capture!(page, "Choose '#{locator}'", target_element: el, action_type: "check") }
        end

        def check(locator = nil, **opts)
          el = begin; find_field(locator); rescue Capybara::ElementNotFound; nil; end
          super.tap { Specbook::Recorders::Screenshot.capture!(page, "Check '#{locator}'", target_element: el, action_type: "check") }
        end

        def uncheck(locator = nil, **opts)
          el = begin; find_field(locator); rescue Capybara::ElementNotFound; nil; end
          super.tap { Specbook::Recorders::Screenshot.capture!(page, "Uncheck '#{locator}'", target_element: el, action_type: "check") }
        end

        def attach_file(locator = nil, path = nil, **opts)
          super.tap { Specbook::Recorders::Screenshot.capture!(page, "Attach file '#{locator}'", action_type: "fill") }
        end

        def accept_confirm(text = nil, &block)
          super.tap { Specbook::Recorders::Screenshot.capture!(page, "Accept confirm dialog", action_type: "confirm") }
        end

        private

        def _find_target_element(locator, opts, type: nil)
          text = locator || opts[:text]
          case type
          when :link
            find_link(text) rescue find(:link, text: text) rescue nil
          when :button
            find_button(text) rescue find(:button, text: text) rescue find(:css, "button", text: text) rescue find(:css, "[type=submit]", text: text) rescue nil
          else
            find(locator) rescue find_link(locator) rescue find_button(locator) rescue find(:css, "button", text: locator) rescue nil
          end
        rescue Capybara::ElementNotFound, Capybara::Ambiguous
          nil
        end
      end

      # Prepend onto Capybara::Session to intercept assertions.
      # After each assertion passes, use Capybara's own finders to locate the matched
      # element and get its bounding box. No independent JS DOM searches.
      module CapybaraSessionAssertionPatch
        def assert_text(*args, **opts)
          super.tap do
            if Specbook::Recorders::Screenshot.current_example_name
              actual_text = args.find { |a| a.is_a?(String) || a.is_a?(Regexp) }
              if actual_text
                text_str = actual_text.to_s
                # Capybara confirmed this text exists — find the element containing it
                bboxes = capybara_text_bbox(text_str)
                Specbook::Recorders::Screenshot.record_assertion!("Has text: '#{text_str.truncate(60)}'", bboxes: bboxes)
              end
            end
          end
        end

        def assert_no_text(*args, **opts)
          if Specbook::Recorders::Screenshot.current_example_name
            actual_text = args.find { |a| a.is_a?(String) || a.is_a?(Regexp) }
            # Passing NOT assertion = success, show green
            Specbook::Recorders::Screenshot.record_assertion!("Confirmed no text: '#{actual_text.to_s.truncate(60)}'")
          end
          super
        end

        def assert_selector(*args, **opts)
          super.tap do
            if Specbook::Recorders::Screenshot.current_example_name
              desc = humanize_selector(args, opts)
              bboxes = capybara_element_bbox(*args, **opts)
              Specbook::Recorders::Screenshot.record_assertion!("Has #{desc}", bboxes: bboxes)
            end
          end
        end

        def assert_no_selector(*args, **opts)
          if Specbook::Recorders::Screenshot.current_example_name
            desc = humanize_selector(args, opts)
            # Passing NOT assertion = success, show green
            Specbook::Recorders::Screenshot.record_assertion!("Confirmed no #{desc}")
          end
          super
        end

        private

        # Convert raw Capybara selector args to human-readable description
        def humanize_selector(args, opts)
          parts = []
          args.each do |a|
            s = a.to_s
            # Clean up CSS selectors: "css span[title='Exempt']" → "'Exempt' element"
            if s =~ /^css$/
              next  # skip the :css symbol, use the next arg
            elsif s =~ /\[title=['"](.*?)['"]\]/
              parts << "'#{$1}' element"
            elsif s =~ /\[class\*=['"](.*?)['"]\]/
              parts << "'#{$1}' styled element"
            elsif s =~ /^\.bg-(\w+)/
              # Tailwind background class — describe the color
              color = $1.sub(/-\d+$/, '')
              parts << "#{color} status indicator"
            elsif s =~ /^[.#\[]/
              # CSS selector — simplify
              clean = s.gsub(/\[.*?\]/, '').gsub(/[.#]/, ' ').strip
              parts << (clean.presence || "element")
            else
              parts << s
            end
          end
          text_filter = opts[:text]
          parts << "'#{text_filter.to_s.truncate(30)}'" if text_filter
          parts.join(" ").presence || "element"
        end

        # Get the page session — works whether self is Session or Node::Element
        def _page_session
          # self IS the page when prepended on Capybara::Session
          # self.session when prepended on Capybara::Node::Base
          self.is_a?(Capybara::Session) ? self : self.session
        end

        # Get bbox of the element Capybara matched for a selector assertion
        def capybara_element_bbox(*args, **opts)
          find_opts = opts.except(:wait, :count, :minimum, :maximum, :between)
          el = find(*args, **find_opts, wait: 0)
          bbox = Specbook::Recorders::Screenshot.get_bounding_box(_page_session, el)
          if !bbox && !self.is_a?(Capybara::Session)
            # Scoped element — try getting bbox of self (the parent) as fallback
            bbox = Specbook::Recorders::Screenshot.get_bounding_box(_page_session, self)
          end
          bbox ? [bbox] : []
        rescue Capybara::ElementNotFound, Capybara::Ambiguous => e
          if e.is_a?(Capybara::Ambiguous)
            el = first(*args, **find_opts, wait: 0)
            bbox = el ? Specbook::Recorders::Screenshot.get_bounding_box(_page_session, el) : nil
            bbox ? [bbox] : []
          elsif !self.is_a?(Capybara::Session)
            # Element not found within scope — highlight the scope element itself
            bbox = Specbook::Recorders::Screenshot.get_bounding_box(_page_session, self)
            bbox ? [bbox] : []
          else
            []
          end
        rescue StandardError
          []
        end

        # Get bbox for a text assertion — find the tightest element via Capybara.
        # Avoids div/section/main/body which are often large container elements.
        # Tries leaf-level tags first, falls back to any element picking smallest bbox.
        def capybara_text_bbox(text_str)
          page_session = _page_session
          escaped = Regexp.escape(text_str)

          # Strategy 1: leaf-level tags only (no div/section/article/main)
          leaf_tags = "p, span, td, th, li, h1, h2, h3, h4, h5, h6, a, label, button, strong, em, small, b, i, mark, code, badge"
          el = page_session.first(:css, leaf_tags, text: /#{escaped}/i, wait: 0)
          if el
            bbox = Specbook::Recorders::Screenshot.get_bounding_box(page_session, el)
            return [bbox] if bbox.is_a?(Hash) && bbox["x"]
          end

          # Strategy 2: any element, but pick the smallest bbox (tightest fit)
          elements = page_session.all(:css, "*", text: /#{escaped}/i, wait: 0)
          best_bbox = nil
          best_area = Float::INFINITY
          elements.each do |candidate|
            bbox = Specbook::Recorders::Screenshot.get_bounding_box(page_session, candidate)
            next unless bbox.is_a?(Hash) && bbox["width"].to_i > 0 && bbox["height"].to_i > 0
            area = bbox["width"] * bbox["height"]
            if area < best_area
              best_area = area
              best_bbox = bbox
            end
          end
          return [best_bbox] if best_bbox

          []
        rescue StandardError => e
          Rails.logger.debug { "[Specbook::Recorders::Screenshot] capybara_text_bbox error: #{e.message}" } if defined?(Rails)
          []
        end
      end

      # Session-level action patches — captures bbox for click/fill/select/choose
      # These prepend on Session so they work from both test class AND step definitions
      module CapybaraSessionActionPatch
        def click_button(locator = nil, **opts)
          el = begin; find_button(locator || opts[:text]); rescue; begin; find(:css, "button", text: locator || opts[:text]); rescue; nil; end; end
          Specbook::Recorders::Screenshot.capture!(self, "Click button '#{locator || opts[:text]}'", target_element: el, action_type: "click")
          super
        end

        def click_link(locator = nil, **opts)
          el = begin
            opts[:href] ? find(:link, href: opts[:href]) : find_link(locator || opts[:text])
          rescue; nil; end
          Specbook::Recorders::Screenshot.capture!(self, "Click link '#{locator || opts[:text] || opts[:href]}'", target_element: el, action_type: "click")
          super
        end

        def click_on(locator = nil, **opts)
          el = begin; find_link(locator); rescue; begin; find_button(locator); rescue; nil; end; end
          Specbook::Recorders::Screenshot.capture!(self, "Click '#{locator}'", target_element: el, action_type: "click")
          super
        end

        def fill_in(locator = nil, with:, **opts)
          el = begin; find_field(locator || opts[:id] || opts[:name]); rescue; nil; end
          super.tap { Specbook::Recorders::Screenshot.capture!(self, "Type '#{with.to_s.truncate(30)}' into '#{locator}'", target_element: el, action_type: "fill") }
        end

        def select(value = nil, from: nil, **opts)
          el = begin; find_field(from); rescue; nil; end
          super.tap { Specbook::Recorders::Screenshot.capture!(self, "Select '#{value}' from '#{from}'", target_element: el, action_type: "select") }
        end

        def choose(locator = nil, **opts)
          # Radio buttons are often sr-only (hidden). Find the visible parent label card by text.
          el = begin; find(:css, "label", text: /\A#{Regexp.escape(locator)}\z/); rescue; begin; find(:css, "label", text: locator); rescue; nil; end; end
          super.tap { Specbook::Recorders::Screenshot.capture!(self, "Choose '#{locator}'", target_element: el, action_type: "check") }
        end

        def check(locator = nil, **opts)
          el = begin; find_field(locator); rescue; nil; end
          super.tap { Specbook::Recorders::Screenshot.capture!(self, "Check '#{locator}'", target_element: el, action_type: "check") }
        end

        def uncheck(locator = nil, **opts)
          el = begin; find_field(locator); rescue; nil; end
          super.tap { Specbook::Recorders::Screenshot.capture!(self, "Uncheck '#{locator}'", target_element: el, action_type: "check") }
        end

        def attach_file(locator = nil, path = nil, **opts)
          super.tap { Specbook::Recorders::Screenshot.capture!(self, "Attach file '#{locator}'", action_type: "fill") }
        end

        def visit(path, **)
          Specbook::Recorders::Screenshot.flush_assertions!(self) if Specbook::Recorders::Screenshot.pending_assertions.present?
          super.tap { Specbook::Recorders::Screenshot.capture!(self, "Navigate to #{path}", action_type: "navigate") }
        end

        def accept_confirm(text = nil, &block)
          super.tap { Specbook::Recorders::Screenshot.capture!(self, "Accept confirm dialog", action_type: "confirm") }
        end
      end

      # Track Gherkin step index for Turnip features — hook into run_step
      module TurnipGherkinTracker
        def run_step(feature_file, step)
          Specbook::Recorders::Screenshot.advance_gherkin_step!

          # Capture step definition source code for the spec player
          begin
            description = step.respond_to?(:description) ? step.description : step.to_s
            matches = methods.map { |m| m.to_s.start_with?("match: ") ? send(m.to_s, description) : nil }.compact
            if matches.first
              method_obj = method(matches.first.method_name)
              source_file, source_line = method_obj.source_location
              params = matches.first.params
              if source_file
                rel_path = source_file.sub(Rails.root.to_s + "/", "")
                lines = File.readlines(source_file)
                # Extract body lines between `step '...' do` and closing `end`
                first_line = lines[source_line - 1]
                step_indent = first_line[/^\s*/].length
                body_lines = []
                (source_line).upto(lines.size - 1) do |i|  # start AFTER the step line
                  line = lines[i]
                  # Stop at closing end (same indent level as step)
                  break if line.rstrip =~ /\A\s{0,#{step_indent}}end\s*\z/
                  body_lines << line
                end
                body = body_lines.join

                # Substitute Turnip params into the source so variables show resolved values.
                # Only replace when the variable is a standalone argument — not after a dot
                # (method call) or before a colon (hash key).
                if params.any?
                  param_names = first_line[/\|([^|]+)\|/, 1]&.split(",")&.map(&:strip) || []
                  param_names.each_with_index do |pname, idx|
                    next unless params[idx]
                    val = params[idx].is_a?(String) ? %("#{params[idx]}") : params[idx].to_s
                    # Negative lookbehind for dot (method call), negative lookahead for colon (hash key)
                    body = body.gsub(/(?<!\.)(?<![:\w])#{Regexp.escape(pname)}(?![\w:])/) { val }
                  end
                end

                Specbook::Recorders::Screenshot.record_step_source!(rel_path, source_line, body)
              end
            end
          rescue StandardError
            # Step source capture is best-effort
          end

          super

          # Capture a screenshot after every Gherkin step so each has at least one image
          # Skip if no page has been visited yet (background setup = blank screen)
          begin
            url = page.current_url rescue nil
            return if url.blank? || url == "about:blank" || url == "data:,"
            Specbook::Recorders::Screenshot.flush_assertions!(page) rescue nil
            if Specbook::Recorders::Screenshot.current_steps.blank? ||
               Specbook::Recorders::Screenshot.current_steps.last&.dig(:gi) != Specbook::Recorders::Screenshot.current_gherkin_idx
              Specbook::Recorders::Screenshot.capture!(page, step.description, action_type: "gherkin") rescue nil
            end
          rescue StandardError
            # Skip
          end
        end
      end
    end
  end

  Capybara::Session.prepend(Specbook::Recorders::CapybaraSessionActionPatch)

  # Apply assertion patch via prepend so it takes priority
  Capybara::Session.prepend(Specbook::Recorders::CapybaraSessionAssertionPatch)
  # Also patch Node::Base so assertions on scoped elements (find(...).have_css) capture too
  Capybara::Node::Base.prepend(Specbook::Recorders::CapybaraSessionAssertionPatch)

  if defined?(Turnip::RSpec::Execute)
    Turnip::RSpec::Execute.prepend(Specbook::Recorders::TurnipGherkinTracker)
  end

  RSpec.configure do |config|
    config.before(:suite) do
      # Create timestamped run directory
      FileUtils.mkdir_p(Specbook::Recorders::Screenshot::SCREENSHOT_DIR)

      # Symlink "latest" for the spec player
      latest = Specbook::Recorders::Screenshot::SCREENSHOT_BASE.join("latest")
      FileUtils.rm_f(latest)
      FileUtils.ln_s(Specbook::Recorders::Screenshot::RUN_TIMESTAMP, latest)

      # Prune old runs beyond MAX_RUNS
      runs = Dir.children(Specbook::Recorders::Screenshot::SCREENSHOT_BASE)
                .select { |d| d =~ /^\d{8}_\d{6}$/ }
                .sort
      if runs.size > Specbook::Recorders::Screenshot::MAX_RUNS
        runs[0..-(Specbook::Recorders::Screenshot::MAX_RUNS + 1)].each do |old|
          FileUtils.rm_rf(Specbook::Recorders::Screenshot::SCREENSHOT_BASE.join(old))
        end
      end
    end

    config.before(:each, type: :system) do |example|
      next if example.metadata[:record] == false
      Specbook::Recorders::Screenshot.reset_for_example!(example, page)
    end

    # Non-UI Turnip features (models, services) run as :model type — no page/browser
    config.before(:each, type: :model) do |example|
      next unless example.metadata[:turnip]
      next if example.metadata[:record] == false
      Specbook::Recorders::Screenshot.current_example_name = example.full_description
      Specbook::Recorders::Screenshot.current_steps = []
      Specbook::Recorders::Screenshot.step_counter = 0
      Specbook::Recorders::Screenshot.pending_assertions = []
      Specbook::Recorders::Screenshot.current_gherkin_idx = -1
      Specbook::Recorders::Screenshot.step_sources = {}
    end

    config.after(:each, type: :system) do |example|
      # Flush any pending assertions as the final step
      Specbook::Recorders::Screenshot.flush_assertions!(page) rescue nil
      # If no assertions were flushed, capture a plain final state
      if Specbook::Recorders::Screenshot.current_steps.present? &&
         Specbook::Recorders::Screenshot.current_steps.last&.dig(:action) != "assert"
        Specbook::Recorders::Screenshot.capture!(page, "Final state", action_type: "assert") rescue nil
      end
      Specbook::Recorders::Screenshot.finalize_example!(example)
    end

    config.after(:each, type: :model) do |example|
      next unless example.metadata[:turnip]
      Specbook::Recorders::Screenshot.finalize_example!(example)
    end

    # Request Turnip features
    config.before(:each, type: :request) do |example|
      next unless example.metadata[:turnip]
      next if example.metadata[:record] == false
      Specbook::Recorders::Screenshot.current_example_name = example.full_description
      Specbook::Recorders::Screenshot.current_steps = []
      Specbook::Recorders::Screenshot.step_counter = 0
      Specbook::Recorders::Screenshot.pending_assertions = []
      Specbook::Recorders::Screenshot.current_gherkin_idx = -1
      Specbook::Recorders::Screenshot.step_sources = {}
    end

    config.after(:each, type: :request) do |example|
      next unless example.metadata[:turnip]
      Specbook::Recorders::Screenshot.finalize_example!(example)
    end

    config.after(:suite) do
      Specbook::Recorders::Screenshot.write_manifest!
      puts "\n📸 Screenshots saved to tmp/spec_screenshots/ (#{Specbook::Recorders::Screenshot.manifest.size} examples recorded)"
    end

    # Action patches now on Capybara::Session via CapybaraSessionActionPatch
  end
end
