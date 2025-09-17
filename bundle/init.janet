(defn install
  [manifest &]
  (bundle/add manifest "janet-native-tools"))

(defn pre-build
  [&]
  (print "Nothing to pre-build!"))

(defn build
  [&]
  (pre-build)
  (print "Nothing to build!"))

(defn clean
  [&]
  (print "Nothing to clean!"))

(defn clean-all
  [&]
  (clean)
  (print "Nothing to clean-all!"))

(defn check
  [&]
  (var pass-count 0)
  (var total-count 0)
  (def failing @[])
  (each dir (sorted (os/dir "test"))
    (def path (string "test/" dir))
    (when (string/has-suffix? ".janet" path)
      (def pass (zero? (os/execute [(dyn *executable* "janet") "--" path] :p)))
      (++ total-count)
      (unless pass (array/push failing path))
      (when pass (++ pass-count))))
  (if (= pass-count total-count)
    (print "All tests passed!")
    (do
      (printf "%d of %d passed." pass-count total-count)
      (print "failing scripts:")
      (each f failing
        (print "  " f))
      (os/exit 1))))
