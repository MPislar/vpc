#' VPC function
#' 
#' Creates a VPC plot and/or plotting data from observed and simulation data
#' @param sim 
#' @param obs
#' @return Either the data for plotting a VPC or a ggplot2 object
#' @export
#' @seealso \link{sim_data}
#' @examples
#' obs <- Theoph
#' colnames(obs) <- c("id", "wt", "dose", "time", "dv")
#' obs <- obs %>%   # create a dummy covariate to show stratification
#'  group_by(id) %>%  
#'  mutate(sex = round(runif(1)))
#' 
#' sim <- sim_data(obs, # the design of the dataset
#'                 model = function(x) { # the model
#'                   pk_oral_1cmt (t = x$time, dose=x$dose * x$wt, ka = x$ka, ke = x$ke, cl = x$cl * x$wt, ruv = list(additive = 0.1))
#'                 }, 
#'                 theta = c(2.774, 0.0718, .0361),                 # parameter values
#'                 omega_mat = c(0.08854,                           # specified as lower triangle by default; 
#'                               0.02421, 0.02241,                  # note: assumed that every theta has iiv, set to 0 if no iiv. 
#'                               0.008069, 0.008639, 0.02862),      
#'                 par_names = c("ka", "ke", "cl"),                 # link the parameters in the model to the thetas/omegas
#'                 n = 500)
#' 
#' vpc_dat <- vpc(sim, obs, stratify = c("sex"))
vpc <- function(sim, obs, 
                bins = "auto",
                n_bins = 8,
                auto_bin_type = "simple",
                obs.dv = "dv",
                sim.dv =  "sdv",
                obs.idv = "time",
                sim.idv = "time",
                obs.id = "id",
                sim.id = "id",
                obs.pred = "pred",
                sim.pred = "pred",
                nonmem = FALSE,
                plot.dv = FALSE,
                stratify = NULL,
                pred_corr = FALSE,
                pred_corr_lower_bnd = 0,
                pi = c(0.05, 0.95), 
                ci = c(0.05, 0.95),
                uloq = NULL, 
                lloq = NULL, 
                plot = TRUE,
                log_y = FALSE,
                log_y_min = 1e-3,
                xlab = NULL, 
                ylab = NULL,
                title = NULL,
                smooth = TRUE,
                theme = "default",
                custom_theme = NULL,
                facet = "wrap") {
  if (class(bins) != "numeric") {
    bins <- auto_bin(obs, auto_bin_type, n_bins, x=obs.idv)
  }
  if (pred_corr) {
    if (nonmem) {
      obs.pred <- "PRED"
      sim.pred <- "PRED"
    }
    if (!obs.pred %in% names(obs)) {
      cat("Warning: Prediction-correction: specified pred-variable not found in observations, trying to get from simulated dataset...")      
      if (!sim.pred %in% names(sim)) {
        cat("Warning: Prediction-correction: specified pred-variable not found in simulated dataset, not able to perform pred-correction!")
        return()
      } else {
        obs[[obs.pred]] <- sim[1:length(obs[,1]), sim.pred]
        cat ("OK")
      }
    } else {
      if (!sim.pred %in% names(sim)) {
        cat("Warning: Prediction-correction: specified pred-variable not found in simulated dataset, not able to perform pred-correction!")
        return()
      }      
    }
    obs$pred <- obs[[obs.pred]]
    sim$pred <- sim[[sim.pred]]
  }
  sim <- format_vpc_input_data(sim, sim.dv, sim.idv, sim.id, lloq, uloq, stratify, bins, log_y, log_y_min, nonmem)
  obs <- format_vpc_input_data(obs, obs.dv, obs.idv, obs.id, lloq, uloq, stratify, bins, log_y, log_y_min, nonmem)
  if (pred_corr) {
    obs <- obs %>% group_by(strat, bin) %>% mutate(pred_bin = mean(pred))
    obs[obs$pred != 0,]$dv <- pred_corr_lower_bnd + (obs[obs$pred != 0,]$dv - pred_corr_lower_bnd) * (obs[obs$pred != 0,]$pred_bin - pred_corr_lower_bnd) / (obs[obs$pred != 0,]$pred - pred_corr_lower_bnd)
    sim <- sim %>% group_by(strat, sim, bin) %>% mutate(pred_bin = mean(pred))
    sim[sim$pred != 0,]$dv <- pred_corr_lower_bnd + (sim[sim$pred != 0,]$dv - pred_corr_lower_bnd) * (sim[sim$pred != 0,]$pred_bin - pred_corr_lower_bnd) / (sim[sim$pred != 0,]$pred - pred_corr_lower_bnd)
  }
  aggr_sim <- data.frame(cbind(sim %>% group_by(strat, sim, bin) %>% summarise(quantile(dv, pi[1])),
                               sim %>% group_by(strat, sim, bin) %>% summarise(quantile(dv, 0.5 )),
                               sim %>% group_by(strat, sim, bin) %>% summarise(quantile(dv, pi[2]))))
  aggr_sim <- aggr_sim[,-grep("(bin.|strat.|sim.)", colnames(aggr_sim))]  
  colnames(aggr_sim)[grep("quantile", colnames(aggr_sim))] <- c("q5", "q50", "q95")
  tmp <- aggr_sim %>% group_by(strat, bin)
  vpc_dat <- data.frame(cbind(tmp %>% summarise(quantile(q5, ci[1])),
                              tmp %>% summarise(quantile(q5, 0.5)),
                              tmp %>% summarise(quantile(q5, ci[2])),
                              tmp %>% summarise(quantile(q50, ci[1])),
                              tmp %>% summarise(quantile(q50, 0.5)),
                              tmp %>% summarise(quantile(q50, ci[2])),
                              tmp %>% summarise(quantile(q95, ci[1])),
                              tmp %>% summarise(quantile(q95, 0.5)),
                              tmp %>% summarise(quantile(q95, ci[2])) ))
  vpc_dat <- vpc_dat[,-grep("(bin.|strat.)", colnames(vpc_dat))]
  colnames(vpc_dat) <- c("strat", "bin", 
                         "q5.5","q5.50","q5.95", 
                         "q50.5","q50.50","q50.95",
                         "q95.5","q95.50","q95.95")
  vpc_dat$bin_min <- rep(bins[1:(length(bins)-1)], length(unique(vpc_dat$strat)) )
  vpc_dat$bin_max <- rep(bins[2:length(bins)], length(unique(vpc_dat$strat)) )
  vpc_dat$bin_mid <- (vpc_dat$bin_min + vpc_dat$bin_max) / 2
  aggr_obs <- data.frame(cbind(obs %>% group_by(strat,bin) %>% summarise(quantile(dv, 0.05)),
                               obs %>% group_by(strat,bin) %>% summarise(quantile(dv, 0.5 )),
                               obs %>% group_by(strat,bin) %>% summarise(quantile(dv, 0.95)) ))
  aggr_obs <- aggr_obs[,-grep("(bin.|strat.|sim.)", colnames(aggr_obs))]
  colnames(aggr_obs) <- c("strat", "bin", "obs5","obs50","obs95")
  aggr_obs$bin_min <- rep(bins[1:(length(bins)-1)], length(unique(aggr_obs$strat)) )
  aggr_obs$bin_max <- rep(bins[2:length(bins)], length(unique(aggr_obs$strat)) )
  aggr_obs$bin_mid <- (aggr_obs$bin_min + aggr_obs$bin_max)/2 
  if(is.null(xlab)) {
    xlab <- obs.idv
  }
  if(is.null(ylab)) {
    ylab <- obs.dv
  }
  pl <- ggplot(vpc_dat, aes(x=bin_mid, y=dv)) + 
    geom_line(aes(y=q50.50), linetype='dashed') 
  if (smooth) {
    pl <- pl + 
      geom_ribbon(aes(x=bin_mid, y=q50.5, ymin=q50.5, ymax=q50.95), alpha=themes[[theme]]$med_area_alpha, fill = themes[[theme]]$med_area) +
      geom_ribbon(aes(x=bin_mid, y=q5.5, ymin=q5.5, ymax=q5.95), alpha=themes[[theme]]$pi_area_alpha, fill = themes[[theme]]$pi_area) +
      geom_ribbon(aes(x=bin_mid, y=q95.5, ymin=q95.5, ymax=q95.95), alpha=themes[[theme]]$pi_area_alpha, fill = themes[[theme]]$pi_area) 
  } else {
    pl <- pl + 
      geom_rect(aes(xmin=bin_min, xmax=bin_max, y=q50.5, ymin=q50.5, ymax=q50.95), alpha=themes[[theme]]$med_area_alpha, fill = themes[[theme]]$med_area) +
      geom_rect(aes(xmin=bin_min, xmax=bin_max, y=q5.5, ymin=q5.5, ymax=q5.95), alpha=themes[[theme]]$pi_area_alpha, fill = themes[[theme]]$pi_area) +
      geom_rect(aes(xmin=bin_min, xmax=bin_max, y=q95.5, ymin=q95.5, ymax=q95.95), alpha=themes[[theme]]$pi_area_alpha, fill = themes[[theme]]$pi_area)     
  }
  pl <- pl +
    geom_line(data=aggr_obs, aes(x=bin_mid, y=obs50), linetype='solid') +
    geom_line(data=aggr_obs, aes(x=bin_mid, y=obs5), linetype='dotted') +
    geom_line(data=aggr_obs, aes(x=bin_mid, y=obs95), linetype='dotted') 
  if (plot.dv) {
    pl <- pl + geom_point(data=obs, aes(x=idv, y = dv))
  }
  bdat <- data.frame(cbind(x=bins, y=NA))
  pl <- pl + 
    geom_rug(data=bdat, sides = "t", aes(x = x, y=y), colour="#333333")
  pl <- pl + xlab(xlab) + ylab(ylab)
  if (log_y) {
    pl <- pl + scale_y_log10() 
  }
  if (!is.null(stratify)) {
    if(facet == "wrap") {
      pl <- pl + facet_wrap(~ strat)      
    } else {
      if(length(grep("row", facet))>0) {
        pl <- pl + facet_grid(strat ~ .)                
      } else {
        pl <- pl + facet_grid(. ~ strat)                
      }
    }
  }
  if (!is.null(title)) {
    pl <- pl + ggtitle(title)  
  }
  if (!is.null(custom_theme)) {  
    pl <- pl + custom_theme()    
  } else {
    if (!is.null(theme)) {
      pl <- pl + theme_plain()
    } 
  }
  if (plot) {
    print(pl)    
  }
  return(
    list(
      obs = tbl_df(obs), 
      sim = tbl_df(sim),
      bins = bins, 
      pl = pl
    )
  )
}