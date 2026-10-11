(use spork/declare-cc)

# pull info.jdn so we don't duplicate symbols there and
# in declare-project below
(def info (-> (slurp "./bundle/info.jdn") parse))

(declare-project
  :name (info :name)
  :description (info :description)
  :version (info :version)
  :dependencies (info :jpm-dependencies))

(declare-source
  :source ["janet-native-tools"])
