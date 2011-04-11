module DataMapper
  module Is
    module Temporal

      class PropertyHelper

        def initialize(base)
          @__properties__ = []
          @__base__ = base
          @__before__ = []
          @__after__ = []
        end

        def property(*args)
          @__properties__ << args
        end

        def before(*args, &block)
          @__before__ << [args, block]
        end

        def after(*args, &block)
          @__after__ << [args, block]
        end

        def has(*args)
          raise 'Temporal associations are not supported yet!'
        end

        def belongs_to(*args)
          raise 'Temporal associations are not supported yet!'
        end

        def __properties__
          @__properties__
        end
      end

      def is_temporal(*args, &block)

        extend(Migration) if respond_to?(:auto_migrate!)

        version_model = DataMapper::Model.new

        if block_given?
          version_model.instance_eval <<-RUBY
            def self.default_repository_name
              :#{default_repository_name}
            end
          RUBY

          version_model.property(:id, DataMapper::Property::Serial)
          version_model.property(:updated_at, DataMapper::Property::DateTime)
          version_model.before(:save) { self.updated_at ||= DateTime.now }
          version_model.instance_eval(&block)

          const_set(:TemporalVersion, version_model)

          h = PropertyHelper.new(self)
          h.instance_eval(&block)

          has n, :temporal_versions

          create_methods

          h.__properties__.each do |a|
            create_temporal_reader(a[0])
            create_temporal_writer(a[0])
          end
        else
          # const_set(:TemporalVersion + args[0], version_model)
          raise "Temporal Property pattern not supported yet"
        end

      end

      private

      def create_methods
        class_eval <<-RUBY

          def self.update(options={})
            raise "Updating all doesn't work yet"
#            t_opts = __select_temporal_options__(options)
#            raise "Can't update at temporal properties from class level yet." if !t_opts.empty?
#            super.update(options)
          end

          def self.all(options={})
            t_opts = __select_temporal_options__(options)
            raise "Can't select all by temporal properties from class level yet." if !t_opts.empty?             
            super.all(options)
          end

          def self.create(options={})
            t_opts = __select_temporal_options__(options)
            options.delete_if {|k,v| t_opts.keys.include?(k) }

            base = super(options)
            base.temporal_versions << TemporalVersion.create(t_opts) if t_opts.size > 0
            base.save
            base
          end

          def at(context=DateTime.now, &block)
            if block_given?
              yield TemporalProxy.new(self, context)
            else
              # this is hokie.  need to do better
              @__at__ = context
            end
            self
          end

          def update(options={})
            cur_t = __version_for_context__
            attrs = cur_t.nil? ? {} : cur_t.attributes
            t_opts = self.class.__select_temporal_options__(options)
            options.delete_if {|k,v| t_opts.keys.include?(k) }
            super(options)

            self.temporal_versions <<
                TemporalVersion.create(attrs.merge(:id => nil, :updated_at => nil).merge(t_opts))

            self.save
          end

          private

          def self.__select_temporal_options__(options={})
            props = TemporalVersion.properties.map {|p| p.name}
            temporal_opts = options.
                select {|k,v| props.include?(k)}.
                inject({}) {|a,b| a.merge({b[0] => b[1]}) }
            return temporal_opts
          end

          def __version_for_context__(context=DateTime.now)
            @__at__ ||= context
            t = nil
            temporal_versions.each do |n|
              if (t.nil? or n.updated_at > t.updated_at) and n.updated_at <= @__at__
                t = n
              end
            end
            @__at__ = nil
            t
          end
        RUBY
      end

      def create_temporal_reader(name)
        class_eval <<-RUBY
          def #{name}(context=DateTime.now)
            t = __version_for_context__(context)
            t.nil? ? nil : t.#{name}
          end
        RUBY
      end

      def create_temporal_writer(name)
        class_eval <<-RUBY
          def #{name}=(x)
            at = @__at__
            t = __version_for_context__
            if t.nil?
              t = TemporalVersion.create(:updated_at => at)
              temporal_versions << t
            elsif t.updated_at != at
              t = TemporalVersion.create(t.attributes.merge(:id => nil, :updated_at => at))
              temporal_versions << t
            end
            t.#{name} = x
            self.save
            #{name}
          end
        RUBY
      end

      class TemporalProxy
        # make this a blank slate
        instance_methods.each { |m| undef_method m unless m =~ /^__/ }

        def initialize(proxied_object, context)
          @proxied_object = proxied_object
          @context = context
        end

        def method_missing(sym, *args, &block)
          @proxied_object.at(@context).__send__(sym, *args, &block)
        end
      end

      module Migration

        def auto_migrate!(repository_name = self.repository_name)
          super
          self::TemporalVersion.auto_migrate!
        end

        def auto_upgrade!(repository_name = self.repository_name)
          super
          self::TemporalVersion.auto_upgrade!
        end

      end 
    end
  end
end
