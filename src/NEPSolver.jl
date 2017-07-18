module NEPSolver
    using NEPCore
    using NEPTypes
    using LinSolvers

    export compute_eigvec_from_eigval_old
    export compute_eigvec_from_eigval
    ## NEP-Methods

    include("method_newton.jl")
    include("method_iar.jl")
    include("method_tiar.jl")
    include("method_infbilanczos.jl")
    include("method_mslp.jl")
    include("method_companion.jl")
    include("method_nlar.jl")
    include("method_sg.jl")
    include("method_rfi.jl")
#    include("method_jd_lin.jl")
    include("method_jd_quad.jl")

"""
     Computes an eigenvector approximation from an
     eigenvalue approximation (with very little
     computational effort). It is not clear how
     this is best achieved.
"""
    function compute_eigvec_from_eigval_old(nep::NEP,λ;
                                        v=ones(size(nep,1)),
                                        tol=sqrt(eps()))
        # Still not sure how to do this in an efficient way
        A=compute_Mder(nep,λ); # This requires matrix access
        δ=1/sqrt(norm(A,1));
        # Do a couple of steps of inverse iteration
        local rv
        for k=1:10
            rv=A*v;
            if (norm(rv)<tol)
                return v # Sufficiently accurate
            end
            v=(A-δ*speye(size(A,1),size(A,2)))\v
            v=v/norm(v);
        end
        warn("No sufficiently accurate eigenvector found. Norm:"*string(norm(rv)))
        return v;
    end

    function compute_eigvec_from_eigval(nep::NEP,λ;
                                        v=ones(size(nep,1)),
                                        tol=sqrt(eps()),
                                        linsolver=0)
        # Still not sure how to do this in an efficient way
        A=compute_Mder(nep,λ); # This requires matrix access

        if (isa(linsolver,:DefaultLinSolver))            
        else
        end
        
        n=size(nep,1)
        M=[A; rand(eltype(A),1,n)]
        b=[zeros(eltype(A),n); 1]
        v=M\b;

        return v;
    end




end #End module
