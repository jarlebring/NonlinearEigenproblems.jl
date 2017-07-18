
# Newton-like methods for NEPs

    export newton
    export resinv
    export augnewton

#############################################################################
"""
    Newton raphsons method on nonlinear equation with (n+1) unknowns
"""
    newton(nep::NEP;params...)=newton(Complex128,nep;params...)
    function newton{T}(::Type{T},
                       nep::NEP;
                       errmeasure::Function =
                       default_errmeasure(nep::NEP),
                       tolerance=eps(real(T))*100,
                       maxit=10,
                       λ=zero(T),
                       v=randn(size(nep,1)),
                       c=v,
                       displaylevel=0)

        # Ensure types λ and v are of type T
        λ=T(λ)
        v=Array{T,1}(v)
        c=Array{T,1}(c)

        err=Inf;
        v=v/dot(c,v);

        try
            for k=1:maxit
                err=errmeasure(λ,v)
                if (displaylevel>0)
                    println("Iteration:",k," errmeasure:",err)
                end
                if (err< tolerance)
                    return (λ,v)
                end

                # Compute NEP matrix and derivative
                M = compute_Mder(nep,λ)
                Md = compute_Mder(nep,λ,1)

                # Create jacobian
                J = [M Md*v; c' 0];
                F = [M*v; c'*v-1];

                # Compute update
                delta=-J\F;  # Hardcoded backslash

                # Update eigenvalue and eigvec
                v[:] += delta[1:size(nep,1)];
                λ = λ+T(delta[size(nep,1)+1]);
            end
        catch e
            isa(e, Base.LinAlg.SingularException) || rethrow(e)
            # This should not cast an error since it means that λ is
            # already an eigenvalue.
            if (displaylevel>0)
                println("We have an exact eigenvalue.")
            end
            if (errmeasure(λ,v)>tolerance)
                # We need to compute an eigvec somehow
                v=(compute_Mder(nep,λ,0)+eps(real(T))*speye(size(nep,1)))\v; # Requires matrix access
                v=v/dot(c,v)
            end
            return (λ,v)
        end
        msg="Number of iterations exceeded. maxit=$(maxit)."
        throw(NoConvergenceException(λ,v,err,msg))
    end

    ############################################################################
"""
    Residual inverse iteration method for nonlinear eigenvalue problems.
"""
    resinv(nep::NEP;params...)=resinv(Complex128,nep;params...)
    function resinv{T}(::Type{T},
                        nep::NEP;
                        errmeasure::Function =
                        default_errmeasure(nep::NEP),
                        tolerance=eps(real(T))*100,
                        maxit=100,
                        λ=zero(T),
                        v=randn(size(nep,1)),
                        c=v,
                        displaylevel=0,
                        linsolvercreator::Function=default_linsolvercreator)

        local linsolver::LinSolver=linsolvercreator(nep,λ)
        # Ensure types λ and v are of type T
        λ::T=T(λ)
        v=Array{T,1}(v)
        c=Array{T,1}(c)

        # If c is zero vector we take eigvec approx as left vector in
        # generalized Rayleigh functional
        use_v_as_rf_vector=false;
        if (norm(c)==0)
            use_v_as_rf_vector=true;
        end


        σ::T=λ;
        err=Inf;

        try
            for k=1:maxit
                # Normalize
                v = v/norm(v);

                err=errmeasure(λ,v)


                if (use_v_as_rf_vector)
                    c=v;
                end

                if (displaylevel>0)
                    @printf("Iteration: %2d errmeasure:%.18e ",k, err);
                    println(" v_as_rf_vector=",use_v_as_rf_vector);
                end

                if (err< tolerance)
                    return (λ,v)
                end

                # Compute eigenvalue update
                λ = compute_rf(T, nep,v,y=c,λ0=λ,target=σ)


                # Compute eigenvector update
                Δv = lin_solve(linsolver,compute_Mlincomb(nep,λ,v)) #M*v);

                # Update the eigvector
                v[:] += -Δv;

            end

        catch e
            isa(e, Base.LinAlg.SingularException) || rethrow(e)
            # This should not cast an error since it means that λ is
            # already an eigenvalue.
            if (displaylevel>0)
                println("We have an exact eigenvalue.")
            end
            if (errmeasure(λ,v)>tolerance)
                # We need to compute an eigvec somehow
                v=(nep.Md(λ,0)+eps(real(T))*speye(size(nep,1)))\v; # Requires matrix access
                v=v/dot(c,v)
            end
            return (λ,v)
        end
        msg="Number of iterations exceeded. maxit=$(maxit)."
        throw(NoConvergenceException(λ,v,err,msg))
    end





    # New augnewton
"""
    Augmented Newton's method. Equivalent to newton() but works only with operations on vectors of length n, instead of n+1.
"""
    augnewton(nep::NEP;params...)=augnewton(Complex128,nep;params...)
    function augnewton{T}(::Type{T},
                           nep::NEP;
                           errmeasure::Function = default_errmeasure(nep::NEP),
                           tolerance=eps(real(T))*100,
                           maxit=30,
                           λ=zero(T),
                           v=randn(size(nep,1)),
                           c=v,
                           displaylevel=0,
                           linsolvercreator::Function=backslash_linsolvercreator)
        # Ensure types λ and v are of type T
        λ=T(λ)
        v=Array{T,1}(v)
        c=Array{T,1}(c)

        err=Inf;
        # If c is zero vector we take eigvec approx as normalization vector
        use_v_as_normalization_vector=false;
        if (norm(c)==0)
            use_v_as_normalization_vector=true;
            c = v /norm(v)^2
        end
        v=v/dot(c,v);
        local linsolver::LinSolver;
        
        try
            for k=1:maxit
                err=errmeasure(λ,v)
                if (displaylevel>0)
                    @printf("Iteration: %2d errmeasure:%.18e ",k, err);
                    println(" v_as_normalization_vector=",use_v_as_normalization_vector);
                end
                if (err< tolerance)
                    return (λ,v)
                end
                # tempvec =  (M(λ_k)^{-1})*M'(λ_k)*v_k
                # α = 1/(c'*(M(λ_k)^{-1})*M'(λ_k)*v_k);

                z=compute_Mlincomb(nep,λ,v,[T(1.0)],1)

                linsolver = linsolvercreator(nep,λ)
                tempvec = lin_solve(linsolver, z, tol=tolerance);

                if (use_v_as_normalization_vector)
                    c = v /norm(v)^2
                end
                α = T(1)/ dot(c,tempvec);

                λ = λ - α;

                v[:] = α*tempvec;

            end

        catch e
            isa(e, Base.LinAlg.SingularException) || rethrow(e)
            # This should not cast an error since it means that λ is
            # already an eigenvalue.
            if (displaylevel>0)
                println("We have an exact eigenvalue.")
            end
            if (errmeasure(λ,v)>tolerance)
                # We need to compute an eigvec somehow
                v= compute_eigvec_from_eigval(nep,λ,v=v,linsolver=linsolver)
                v=v/dot(c,v)
            end
            return (λ,v)
        end

        msg="Number of iterations exceeded. maxit=$(maxit)."
        throw(NoConvergenceException(λ,v,err,msg))
    end
