require 'spec_helper'
require 'brainstem/api_docs/endpoint'

module Brainstem
  module ApiDocs
    describe Endpoint do
      let(:lorem)   { "lorem ipsum dolor sit amet" }
      let(:atlas)   { Object.new }
      let(:options) { {} }
      subject       { described_class.new(atlas, options) }


      describe "#initialize" do
        it "yields self if given a block" do
          block = Proc.new { |s| s.path = "bork bork" }
          expect(described_class.new(atlas, &block).path).to eq "bork bork"
        end
      end


      describe "#merge_http_methods!" do
        let(:options) { { http_methods: %w(GET) } }

        it "adds http methods that are not already present" do

          expect(subject.http_methods).to eq %w(GET)
          subject.merge_http_methods!(%w(POST PATCH GET))
          expect(subject.http_methods).to eq %w(GET POST PATCH)
        end
      end


      describe "configured fields" do
        let(:const) do
          Class.new do
            def self.brainstem_model_name
              :widget
            end
          end
        end

        let(:controller)     { Object.new }
        let(:action)         { :show }

        let(:lorem)          { "lorem ipsum dolor sit amet" }
        let(:default_config) { {} }
        let(:show_config)    { {} }
        let(:nodoc)          { false }

        let(:configuration)  {
          {
            :_default => default_config,
            :show     => show_config,
          }
        }

        let(:options) { { controller: controller, action: action } }

        before do
          stub(controller).configuration { configuration }
          stub(controller).const { const }
        end


        describe "#nodoc?" do
          let(:show_config) { { nodoc: nodoc } }

          context "when nodoc" do
            let(:nodoc) { true }

            it "is true" do
              expect(subject.nodoc?).to eq true
            end
          end

          context "when documentable" do
            it "is false" do
              expect(subject.nodoc?).to eq false
            end
          end
        end


        describe "#title" do
          context "when present" do
            let(:show_config) { { title: { info: lorem, nodoc: nodoc } } }

            context "when nodoc" do
              let(:nodoc) { true }

              it "uses the action name" do
                expect(subject.title).to eq "Show"
              end
            end

            context "when documentable" do
              it "formats the title as an h4" do
                expect(subject.title).to eq lorem
              end
            end
          end

          context "when absent" do
            it "falls back to the action name" do
              expect(subject.title).to eq "Show"
            end
          end
        end


        describe "#description" do
          context "when present" do
            let(:show_config) { { description: { info: lorem, nodoc: nodoc } } }

            context "when nodoc" do
              let(:nodoc) { true }

              it "shows nothing" do
                expect(subject.description).to be_empty
              end
            end

            context "when not nodoc" do
              it "shows the description" do
                expect(subject.description).to eq lorem
              end
            end
          end

          context "when not present" do
            it "shows nothing" do
              expect(subject.description).to be_empty
            end
          end
        end


        describe "#valid_params" do
          it "returns the valid_params key from action or default" do
            mock(subject).key_with_default_fallback(:valid_params)
            subject.valid_params
          end
        end


        describe "#params_configuration_tree" do
          let(:default_config) { { valid_params: which_param } }

          context "non-nested params" do
            let(:root_param)  { { title: { nodoc: nodoc, type: 'string' } } }
            let(:which_param) { root_param }

            context "when nodoc" do
              let(:nodoc) { true }

              it "rejects the key" do
                expect(subject.params_configuration_tree).to be_empty
              end
            end

            context "when not nodoc" do
              let(:nodoc) { false }

              it "lists it as a root param" do
                expect(subject.params_configuration_tree).to eq(
                  {
                    title: { nodoc: nodoc, type: 'string' }
                  }.with_indifferent_access
                )
              end

              context "when param has an item" do
                let(:which_param) { { only: { nodoc: nodoc, type: 'array', item: 'integer' } } }

                it "lists it as a root param" do
                  expect(subject.params_configuration_tree).to eq(
                    {
                      only: { nodoc: nodoc, type: 'array', item: 'integer' }
                    }.with_indifferent_access
                  )
                end
              end
            end
          end

          context "nested params" do
            let(:nested_param) { { title: { nodoc: nodoc, type: 'string', root: :sprocket } } }
            let(:which_param)  { nested_param }

            context "when nodoc" do
              let(:nodoc) { true }

              it "rejects the key" do
                expect(subject.params_configuration_tree).to be_empty
              end
            end

            context "when not nodoc" do
              it "lists it as a nested param" do
                expect(subject.params_configuration_tree).to eq(
                  {
                    sprocket: {
                      type: 'hash',
                      children: {
                        title: {
                          nodoc: nodoc,
                          type: 'string',
                          root: :sprocket
                        }
                      }
                    }
                  }.with_indifferent_access
                )
              end

              context "when nested param has an item" do
                let(:which_param) {
                  {
                    ids: { nodoc: nodoc, type: 'array', item: 'integer', root: :sprocket }
                  }
                }

                it "lists it as a nested param" do
                  expect(subject.params_configuration_tree).to eq(
                    {
                      sprocket: {
                        type: 'hash',
                        children: {
                          ids: {
                            nodoc: nodoc,
                            type: 'array',
                            item: 'integer',
                            root: :sprocket
                          }
                        }
                      }
                    }.with_indifferent_access
                  )
                end
              end
            end
          end

          context "proc nested params" do
            let!(:root_proc)        { Proc.new { |klass| klass.brainstem_model_name } }
            let(:proc_nested_param) { { title: { nodoc: nodoc, type: 'string', root: root_proc } } }
            let(:which_param)       { proc_nested_param }

            context "when nodoc" do
              let(:nodoc) { true }

              it "rejects the key" do
                expect(subject.params_configuration_tree).to be_empty
              end
            end

            context "when not nodoc" do
              it "evaluates the proc in the controller's context and lists it as a nested param" do
                mock.proxy(const).brainstem_model_name

                result = subject.params_configuration_tree
                expect(result.keys).to eq(%w(widget))

                children_of_the_root = result[:widget][:children]
                expect(children_of_the_root.keys).to eq(%w(title))

                title_param = children_of_the_root[:title]
                expect(title_param.keys).to eq(%w(nodoc type root))
                expect(title_param[:nodoc]).to eq(nodoc)
                expect(title_param[:type]).to eq('string')
                expect(title_param[:root]).to be_a(Proc)
              end
            end
          end

          context "multi nested params" do
            context "has a root & ancestors" do
              let(:which_param) {
                {
                  id: {
                    type: 'integer'
                  },
                  task: {
                    type: 'hash',
                    root: 'project'
                  },
                  title: {
                    type: 'string',
                    root: 'project',
                    ancestors: %w(task)
                  },
                  checklist: {
                    type: 'array',
                    item: 'hash',
                    root: 'project',
                    ancestors: %w(task)
                  },
                  name: {
                    type: 'string',
                    root: 'project',
                    ancestors: %w(task checklist)
                  }
                }
              }

              context "when a leaf param has no doc" do
                before do
                  which_param[:name][:nodoc] = true
                end

                it "rejects the key" do
                  expect(subject.params_configuration_tree).to eq(
                    {
                      id: {
                        type: 'integer',
                      },
                      project: {
                        type: 'hash',
                        children: {
                          task: {
                            type: 'hash',
                            root: 'project',
                            children: {
                              title: {
                                type: 'string',
                                root: 'project',
                                ancestors: %w(task)
                              },
                              checklist: {
                                type: 'array',
                                item: 'hash',
                                root: 'project',
                                ancestors: %w(task)
                              },
                            },
                          },
                        },
                      },
                    }.with_indifferent_access
                  )
                end
              end

              context "when nodoc on a parent param" do
                before do
                  which_param[:checklist][:nodoc] = true
                end

                it "rejects the parent key and its children" do
                  expect(subject.params_configuration_tree).to eq(
                    {
                      id: {
                        type: 'integer',
                      },
                      project: {
                        type: 'hash',
                        children: {
                          task: {
                            type: 'hash',
                            root: 'project',
                            children: {
                              title: {
                                type: 'string',
                                root: 'project',
                                ancestors: %w(task)
                              },
                            },
                          },
                        },
                      },
                    }.with_indifferent_access
                  )
                end
              end

              context "when not nodoc" do
                it "evaluates the proc in the controller's context and lists it as a nested param" do
                  expect(subject.params_configuration_tree).to eq(
                    {
                      id: {
                        type: 'integer',
                      },
                      project: {
                        type: 'hash',
                        children: {
                          task: {
                            type: 'hash',
                            root: 'project',
                            children: {
                              title: {
                                type: 'string',
                                root: 'project',
                                ancestors: %w(task)
                              },
                              checklist: {
                                type: 'array',
                                item: 'hash',
                                root: 'project',
                                ancestors: %w(task),
                                children: {
                                  name: {
                                    type: 'string',
                                    root: 'project',
                                    ancestors: %w(task checklist)
                                  },
                                },
                              },
                            },
                          },
                        },
                      },
                    }.with_indifferent_access
                  )
                end
              end
            end

            context "has only ancestors" do
              let(:which_param) {
                {
                  task: {
                    type: 'hash',
                  },
                  title: {
                    type: 'string',
                    ancestors: %w(task)
                  },
                  checklist: {
                    type: 'array',
                    item: 'hash',
                    ancestors: %w(task)
                  },
                  name: {
                    type: 'string',
                    ancestors: %w(task checklist)
                  }
                }
              }

              context "when a leaf param has no doc" do
                before do
                  which_param[:name][:nodoc] = true
                end

                it "rejects the key" do
                  expect(subject.params_configuration_tree).to eq(
                    {
                      task: {
                        type: 'hash',
                        children: {
                          title: {
                            type: 'string',
                            ancestors: %w(task)
                          },
                          checklist: {
                            type: 'array',
                            item: 'hash',
                            ancestors: %w(task)
                          },
                        },
                      },
                    }.with_indifferent_access
                  )
                end
              end

              context "when parent param has nodoc" do
                before do
                  which_param[:checklist][:nodoc] = true
                end

                it "rejects the parent key and its children" do
                  expect(subject.params_configuration_tree).to eq(
                    {
                      task: {
                        type: 'hash',
                        children: {
                          title: {
                            type: 'string',
                            ancestors: %w(task)
                          },
                        },
                      }
                    }.with_indifferent_access
                  )
                end
              end

              context "when not nodoc" do
                it "evaluates the proc in the controller's context and lists it as a nested param" do
                  expect(subject.params_configuration_tree).to eq(
                    {
                      task: {
                        type: 'hash',
                        children: {
                          title: {
                            type: 'string',
                            ancestors: %w(task)
                          },
                          checklist: {
                            type: 'array',
                            item: 'hash',
                            ancestors: %w(task),
                            children: {
                              name: {
                                type: 'string',
                                ancestors: %w(task checklist)
                              },
                            },
                          },
                        },
                      },
                    }.with_indifferent_access
                  )
                end
              end
            end
          end
        end


        describe "#valid_presents" do
          it "returns the presents key from action or default" do
            mock(subject).key_with_default_fallback(:presents)
            subject.valid_presents
          end
        end


        describe "#contextual_documentation" do
          let(:show_config) { { title: { info: info, nodoc: nodoc } } }
          let(:info)           { lorem }

          context "when has the key" do
            let(:key) { :title }

            context "when not nodoc" do
              context "when has info" do
                it "is truthy" do
                  expect(subject.contextual_documentation(key)).to be_truthy
                end

                it "is the info" do
                  expect(subject.contextual_documentation(key)).to eq lorem
                end
              end

              context "when has no info" do
                let(:info) { nil }

                it "is falsey" do
                  expect(subject.contextual_documentation(key)).to be_falsey
                end
              end
            end

            context "when nodoc" do
              let(:nodoc) { true }

              it "is falsey" do
                expect(subject.contextual_documentation(key)).to be_falsey
              end
            end
          end

          context "when doesn't have the key" do
            let(:key) { :herp }

            it "is falsey" do
              expect(subject.contextual_documentation(key)).to be_falsey
            end
          end
        end


        describe "#key_with_default_fallback" do
          let(:default_config) { { info: "default" } }

          context "when it has the key in the action config" do
            let(:show_config)    { { info: "show" } }

            it "returns that" do
              expect(subject.key_with_default_fallback(:info)).to eq "show"
            end
          end

          context "when it has the key only in the default config" do
            it "returns that" do
              expect(subject.key_with_default_fallback(:info)).to eq "default"
            end
          end
        end
      end


      describe "#sort" do
        actions = %w(index show create update delete articuno zapdos moltres)

        actions.each do |axn|
          let(axn.to_sym) { described_class.new(atlas, action: axn.to_sym) }
        end

        let(:axns) { actions.map {|axn| send(axn.to_sym) } }

        it "orders appropriately" do
          sorted = axns.reverse.sort
          expect(sorted[0]).to eq index
          expect(sorted[1]).to eq show
          expect(sorted[2]).to eq create
          expect(sorted[3]).to eq update
          expect(sorted[4]).to eq delete
          expect(sorted[5]).to eq articuno
          expect(sorted[6]).to eq moltres
          expect(sorted[7]).to eq zapdos
        end
      end


      describe "#presenter_title" do
        let(:presenter) { mock!.title.returns(lorem).subject }
        let(:options)   { { presenter: presenter } }

        it "returns the presenter's title" do
          expect(subject.presenter_title).to eq lorem
        end
      end


      describe "#relative_presenter_path_from_controller" do
        let(:presenter) {
          mock!
            .suggested_filename_link(:markdown)
            .returns("objects/sprocket_widget")
            .subject
        }

        let(:controller) {
          mock!
            .suggested_filename_link(:markdown)
            .returns("controllers/api/v1/sprocket_widgets_controller")
            .subject
        }

        let(:options) { { presenter: presenter, controller: controller } }

        it "returns a relative path" do
          expect(subject.relative_presenter_path_from_controller(:markdown)).to \
            eq "../../../objects/sprocket_widget"
        end
      end


      it_behaves_like "formattable"
      it_behaves_like "atlas taker"
    end
  end
end
