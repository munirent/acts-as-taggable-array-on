module ActsAsTaggableArrayOn
  module Taggable
    def self.included(base)
      base.extend(ClassMethod)
    end

    module ClassMethod
      def acts_as_taggable_array_on(*tag_def)
        tag_name = tag_def.first
        parser = ActsAsTaggableArrayOn.parser

        scope :"with_any_#{tag_name}", ->(tags){ where("#{tag_name} && ARRAY[?]::varchar[]", parser.parse(tags)) }
        scope :"with_all_#{tag_name}", ->(tags){ where("#{tag_name} @> ARRAY[?]::varchar[]", parser.parse(tags)) }
        scope :"without_any_#{tag_name}", ->(tags){ where.not("#{tag_name} && ARRAY[?]::varchar[]", parser.parse(tags)) }
        scope :"without_all_#{tag_name}", ->(tags){ where.not("#{tag_name} @> ARRAY[?]::varchar[]", parser.parse(tags)) }

        define_method :"#{tag_name}=" do |value|
          write_attribute tag_name,
            case value
            when String then value.split(",").map(&:strip)
            else value
            end
        end

        define_method :"#{tag_name}_text" do
          (read_attribute(tag_name) || []).join ","
        end

        self.class.class_eval do
          define_method :"all_#{tag_name}" do |options = {}, &block|
            subquery_scope = unscoped.select("unnest(#{table_name}.#{tag_name}) as tag").uniq
            subquery_scope = subquery_scope.instance_eval(&block) if block

            from(subquery_scope).pluck('tag')
          end

          define_method :"#{tag_name}_cloud" do |options = {}, &block|
            subquery_scope = unscoped.select("unnest(#{table_name}.#{tag_name}) as tag")
            subquery_scope = subquery_scope.instance_eval(&block) if block

            from(subquery_scope).group('tag').order('tag').pluck('tag, count(*) as count')
          end
        end
      end
    end
  end
end
