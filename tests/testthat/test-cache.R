context('cache function')

# Set up test fixture
# Set up local database for now
# https://github.com/hadley/dplyr/blob/master/vignettes/notes/postgres-setup.Rmd
describe("cache function", {

   db_test_that("blacklisting NAs retains caching when values are NA", {
     expect_cached(blacklist = list(NA), {
       df_ref <- batch_data(1:5, na = TRUE)
       df_cached <- cached_fcn(key = 1:5, model_version, type, na = TRUE) 
       # Rows with a single NA value should have been cached.
       df_cached <- cached_fcn(key = 1:5, model_version, type) 
       expect_true(any(is.na(df_cached)))
     })
   })

   db_test_that("blacklisting NAs does not retain caching when all rows are NA", {
     expect_cached(blacklist = list(NA), {
       df_ref <- batch_data(1:5)
       df_cached <- cached_fcn(key = 1:5, model_version, type, na = "all")
       # Rows with all NA value should not have been cached.
       df_cached <- cached_fcn(key = 1:5, model_version, type)
       expect_false(any(is.na(df_cached)))
     })
   })

   db_test_that("calling the cached function for the first time populated a new table", {
     # First remove all tables in the local database.
     expect_cached({
       df_ref <- batch_data(1:5)
       df_cached <- cached_fcn(key = 1:5, model_version, type)
     })
   })
  
   db_test_that("We can cache big tables", {
     cached_fcn <- cache(batch_huge_data, key = c(key = "id"), c("version"), con = test_con, prefix = "huge_data")
     lapply(list(1:10, 1:20), function(ids) {
       # Populate the cache and make sure that the results are equal
       expect_equal(dim(bd <- batch_huge_data(ids)), dim(cached_fcn(ids)))
       tmp <- cached_fcn(ids)
       # And the results are still correct
       expect_equal(dim(bd), dim(tmp))
     })
     # And now everything is so cached
     tmp <- cached_fcn(1:20)
   })

   db_test_that("retrieving partial result from cache works", {
     expect_cached({
       df_ref <- batch_data(1:5)
       cached_fcn(key = 1:5, model_version, type)
       expect_almost_equal(df_ref[1, ], cached_fcn(key = 1, model_version, type))
     })
   })

   db_test_that("attempting to populate a new row with a different value fails due to cache hit", {
     expect_cached({
       df_ref <- batch_data(1:5, switch = TRUE, flip = 4:5)
       cached_fcn(key = 1:5, model_version, type, switch = TRUE, flip = 4:5)
       cached_fcn(key = 4, model_version, type)
       cached_df <- cached_fcn(1:5, switch = TRUE, flip = 4:5)
     })
   })

   db_test_that("appending partially overlapped table adds to cache", {
     expect_cached({
       df_ref <- batch_data(1:5, model_version, type, switch = TRUE, flip = 1)
       df_ref <- rbind(df_ref, batch_data(6, model_version, type))
       cached_fcn(key = 1:5, model_version, type, switch = TRUE, flip = 1)
       cached_fcn(key = 5:6, model_version, type)
     })
   })

   db_test_that("re-arranging in the correct order happens when using the cache", {
     expect_cached({
       df_ref <- batch_data(1:5, model_version, type)
       cached_fcn(key = 1:5, model_version, type)
       expect_almost_equal(without_rownames(df_ref[5:1, ]),
                    without_rownames(cached_fcn(key = 5:1, model_version, type)))
     }, no_check = TRUE)
   })

   db_test_that("re-arranging in the correct order happens when using the cache with partially new results", {
     expect_cached({
       df_ref <- batch_data(1:5, model_version, type)
       cached_fcn(key = 1:3, model_version, type)
       expect_almost_equal(without_rownames(df_ref[5:1, ]),
                    without_rownames(cached_fcn(key = 5:1, model_version, type)))
     }, no_check = TRUE)
   })

  db_test_that("non-numeric primary keys are supported", {
    expect_cached({
      df_ref <- batch_data(letters[1:5])
      cached_fcn(key = letters[1:5], model_version, type)
      expect_almost_equal(df_ref[1, ], cached_fcn(key = 'a', model_version, type))
    })
  })

  db_test_that("if bind_rows doesn't work, rbind.fill will be used", {
    with_mock(`dplyr::bind_rows` = function(...) stop("bind_rows is broken!"), {
      expect_cached({
        df_ref <- batch_data(1:5)
        df_cached <- cached_fcn(key = 1:5, model_version, type)
      })
    })
  })

  db_test_that("the force. parameter triggers cache re-population", {
    # First remove all tables in the local database.
    expect_cached({
      df_ref <- batch_data(1:5)
      testthatsomemore::package_stub("cachemeifyoucan", "write_data_safely", function(...) {
        stop("Caching layer should not be used")
      }, {
        expect_error(df_cached <- cached_fcn(key = 1:5, model_version, type, force. = FALSE),
                     "Caching layer should not be used")
      })
      df_cached <- cached_fcn(key = 1:5, model_version, type, force. = TRUE)
    })
  })

})

