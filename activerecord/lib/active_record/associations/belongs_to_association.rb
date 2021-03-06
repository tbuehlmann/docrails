module ActiveRecord
  # = Active Record Belongs To Associations
  module Associations
    class BelongsToAssociation < AssociationProxy #:nodoc:
      def create(attributes = {})
        replace(@reflection.create_association(attributes))
      end

      def build(attributes = {})
        replace(@reflection.build_association(attributes))
      end

      def replace(record)
        counter_cache_name = @reflection.counter_cache_column

        if record.nil?
          if counter_cache_name && @owner.persisted?
            @reflection.klass.decrement_counter(counter_cache_name, previous_record_id) if @owner[@reflection.primary_key_name]
          end

          @target = @owner[@reflection.primary_key_name] = nil
        else
          raise_on_type_mismatch(record)

          if counter_cache_name && @owner.persisted? && record.id != @owner[@reflection.primary_key_name]
            @reflection.klass.increment_counter(counter_cache_name, record.id)
            @reflection.klass.decrement_counter(counter_cache_name, @owner[@reflection.primary_key_name]) if @owner[@reflection.primary_key_name]
          end

          @target = (AssociationProxy === record ? record.target : record)
          @owner[@reflection.primary_key_name] = record_id(record) if record.persisted?
          @updated = true
        end

        set_inverse_instance(record)

        loaded
        record
      end

      def updated?
        @updated
      end

      def stale_target?
        if @target && @target.persisted?
          target_id   = @target.send(@reflection.association_primary_key).to_s
          foreign_key = @owner.send(@reflection.primary_key_name).to_s

          target_id != foreign_key
        else
          false
        end
      end

      private
        def find_target
          find_method = if @reflection.options[:primary_key]
                          "find_by_#{@reflection.options[:primary_key]}"
                        else
                          "find"
                        end

          options = @reflection.options.dup.slice(:select, :include, :readonly)

          the_target = with_scope(:find => @scope[:find]) do
            @reflection.klass.send(find_method,
              @owner[@reflection.primary_key_name],
              options
            ) if @owner[@reflection.primary_key_name]
          end
          set_inverse_instance(the_target)
          the_target
        end

        def construct_find_scope
          { :conditions => conditions }
        end

        def foreign_key_present
          !@owner[@reflection.primary_key_name].nil?
        end

        # NOTE - for now, we're only supporting inverse setting from belongs_to back onto
        # has_one associations.
        def invertible_for?(record)
          inverse = inverse_reflection_for(record)
          inverse && inverse.macro == :has_one
        end

        def record_id(record)
          record.send(@reflection.options[:primary_key] || :id)
        end

        def previous_record_id
          @previous_record_id ||= if @reflection.options[:primary_key]
                                    previous_record = @owner.send(@reflection.name)
                                    previous_record.nil? ? nil : previous_record.id
                                  else
                                    @owner[@reflection.primary_key_name]
                                  end
        end
    end
  end
end
