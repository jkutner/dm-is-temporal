module DataMapper
  module Is
    module Temporal

      class PropertyHelper

        def initialize(base)
          @__properties__ = []
          @__has__ = []
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

        def has(multiplicity, *args)
          opts = args.last.is_a?(Hash) ? args.pop : {}
          name = args.shift
          raise "Associations :through option is not yet supported!" if opts[:through]
          @__has__ << [multiplicity, name, args, opts]
        end

        def belongs_to(*args)
          raise 'Temporal associations are not supported yet!'
        end

        def n
          nil
        end

        def __properties__
          @__properties__
        end

        def __has__
          @__has__
        end
      end

      @@__temporal_classes__ = []

      def __temporal_classes__
        @@__temporal_classes__
      end
      protected :__temporal_classes__

      def is_temporal(*args, &block)

        extend(Migration) if respond_to?(:auto_migrate!)

        version_model = DataMapper::Model.new do
          def has(*args)
            #ignore all
          end
        end

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
          @@__temporal_classes__ << self::TemporalVersion

          h = PropertyHelper.new(self)
          h.instance_eval(&block)

          has n, :temporal_versions #, :accessor => :protected

          create_methods

          h.__properties__.each do |a|
            create_temporal_reader(a[0])
            create_temporal_writer(a[0])
          end


          h.__has__.each do |a|
            has_args = a[2]
            plural_name = a[1]

            if has_args.any? and has_args[0].is_a?(String)
              clazz = has_args[0]
              table = DataMapper::Inflector.tableize(clazz)
              singular_name = DataMapper::Inflector.singularize(table)
            else
              singular_name = DataMapper::Inflector.singularize(plural_name.to_s)
            end


            list_model = DataMapper::Model.new

            list_model.instance_eval <<-RUBY
              def self.default_repository_name
                :#{default_repository_name}
              end
            RUBY

            list_model.property(:id, DataMapper::Property::Serial)
            list_model.property(:updated_at, DataMapper::Property::DateTime)
            list_model.property(:deleted_at, DataMapper::Property::DateTime)
            list_model.before(:save) { self.updated_at ||= DateTime.now }
            list_model.belongs_to singular_name #, :accessor => :protected

            temporal_list_name = "temporal_#{plural_name}".to_sym

            list_model_name = Inflector.classify("temporal_#{singular_name}")

            const_set(list_model_name.to_sym, list_model)
            @@__temporal_classes__ << eval("self::#{list_model_name}")

            has n, temporal_list_name, list_model_name

            create_temporal_list_reader(plural_name, singular_name, temporal_list_name, list_model_name)
#            create_temporal_list_writer(a[1], temporal_list)
          end
        else
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
            if base.save and t_opts.size > 0
              base.temporal_versions << TemporalVersion.create(t_opts)
              base.save
            end
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

          def temporal_version_id(context=DateTime.now)
            t = __version_for_context__(context)
            t.nil? ? nil : t.id
          end

          private

          def self.__select_temporal_options__(options={})
            props = TemporalVersion.properties.map {|p| p.name}
            temporal_opts = options.to_hash.
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

          def __versions_for_context__(temporal_list_name, context=DateTime.now)
            @__at__ ||= context
            t = self.__send__(temporal_list_name).select do |n|
              (t.nil? or n.updated_at > t.updated_at) and n.updated_at <= @__at__ and (n.deleted_at.nil? or (n.deleted_at > @__at__))
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
            x
          end
        RUBY
      end

      def create_temporal_list_reader(plural_name, singular_name, temporal_list_name, temporal_list_model)
        class_eval <<-RUBY
          def #{plural_name}(context=DateTime.now)
            at = @__at__
            at ||= context
            versions = __versions_for_context__(#{temporal_list_name.inspect}, context)
            TemporalListProxy.new(
              self,
              versions.map {|v| v.#{singular_name}},
              #{temporal_list_model},
              #{temporal_list_name.to_sym.inspect},
              #{singular_name.to_sym.inspect},
              at)
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

      class TemporalListProxy
        # make this a blank slate
        instance_methods.each { |m| undef_method m unless m =~ /^__/ }

        def initialize(base_object, list, temporal_list_model, temporal_list_name, name, context)
          @base_object = base_object
          @list = list
          @temporal_list_name = temporal_list_name
          @temporal_list_model = temporal_list_model
          @name = name
          @context = context

          @bidirectional_method = DataMapper::Inflector.singularize(
              DataMapper::Inflector.tableize(base_object.class.name.split('::').last))
        end

        def <<(x)
          new_model = @temporal_list_model.create(:updated_at => @context, @name => x)
          if x.respond_to?("#{@bidirectional_method}=")
            x.send("#{@bidirectional_method}=", @base_object)
          end
          @base_object.send(@temporal_list_name) << new_model
          @list << x
        end

        def clear
          @base_object.send(@temporal_list_name).each do |temporal|
            temporal.deleted_at = @context
          end
        end

        def []=(x,y)
          raise "Unsupported method"
        end

        def map!
          raise "Unsupported method"
        end

        def collect!
          raise "Unsupported method"
        end

        def compact!
          raise "Unsupported method"
        end

        def delete(obj)
          @base_object.send(@temporal_list_name).each do |temporal|
            if temporal.send(@name) == obj
              temporal.deleted_at = @context
              return true
            end
          end
        end

        def delete_at(i)
          # probably won't ever support this - not really doing order
          raise "Unsupported method"
        end

        def delete_if
          @base_object.send(@temporal_list_name).each do |temporal|
            if yield(temporal.send(@name))
              temporal.deleted_at = @context
            end
          end
        end

        def drop(i)
          raise "Unsupported method"
        end

        def drop_while(i)
          raise "Unsupported method"
        end

        def fill(*args)
          raise "Unsupported method"
        end

        def flatten!(level=nil)
          raise "Unsupported method"
        end

        def replace(other_array=nil)
          raise "Unsupported method"
        end

        def insert(index, *args)
          raise "Unsupported method"
        end

        def pop
          temporal = @base_object.send(@temporal_list_name).last
          temporal.deleted_at = @context
          temporal.send(@name)
        end

        def push(*obj)
          obj.each do |o|
            self.<< o
          end
        end

        def rehject!
          raise "Unsupported method"
        end

        def reverse!
          raise "Unsupported method"
        end

        def shuffle!
          raise "Unsupported method"
        end

        def slice(*args)
          raise "Unsupported method"
        end

        def sort!
          raise "Unsupported method"
        end

        def uniq!
          raise "Unsupported method"
        end

        def method_missing(sym, *args, &block)
          @list.__send__(sym, *args, &block)
        end
      end

      module Migration

        def auto_migrate!(repository_name = self.repository_name)
          super(repository_name)
          self::__temporal_classes__.each do |t|
            t.auto_migrate!
          end
        end

        def auto_upgrade!(repository_name = self.repository_name)
          super(repository_name)
          self::__temporal_classes__.each do |t|
            t.auto_upgrade!
          end
        end

      end
    end
  end
end
