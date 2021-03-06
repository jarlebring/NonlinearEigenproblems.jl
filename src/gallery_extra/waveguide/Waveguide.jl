

###########################################################
# Waveguide eigenvalue problem (WEP)
# Sum of products of matrices and functions (SPMF)
"""
 Waveguide eigenvalue problem (WEP)
Sum of products of matrices and functions (SPMF)
"""
function assemble_waveguide_spmf_fd(nx::Integer, nz::Integer, hx, Dxx::SparseMatrixCSC, Dzz::SparseMatrixCSC, Dz::SparseMatrixCSC, C1::SparseMatrixCSC, C2T::SparseMatrixCSC, K::Union{Array{Complex128,2},Array{Float64,2}}, Km, Kp, pre_Schur_fact::Bool)
    Ix = speye(Complex128,nx,nx)
    Iz = speye(Complex128,nz,nz)
    Q0 = kron(Ix, Dzz) + kron(Dxx, Iz) + spdiagm(vec(K))
    Q1 = kron(Ix, 2*Dz)
    Q2 = kron(Ix, Iz)

    A = Array{SparseMatrixCSC}(3+2*nz)
    A[1] = hvcat((2,2), Q0, C1, C2T, spzeros(Complex128,2*nz, 2*nz) )
    A[2] = hvcat((2,2), Q1, spzeros(Complex128,nx*nz, 2*nz), spzeros(Complex128,2*nz, nx*nz), spzeros(Complex128,2*nz, 2*nz) )
    A[3] = hvcat((2,2), Q2, spzeros(Complex128,nx*nz, 2*nz), spzeros(Complex128,2*nz, nx*nz), spzeros(Complex128,2*nz, 2*nz) )

    f = Array{Function}(3+2*nz)
    f[1] = λ -> eye(Complex128,size(λ,1),size(λ,2))
    f[2] = λ -> λ
    f[3] = λ -> λ^2

    R, Rinv = generate_R_matvecs(nz)
    S = generate_S_function(nz, hx, Km, Kp)

    for j = 1:nz
        f[j+3] = λ -> S(λ, j)
        e_j = zeros(nz)
        e_j[j] = 1
        E_j = [R(e_j); spzeros(Complex128,nz)]
        E_j = E_j * (E_j/nz)'
        A[j+3] =  hvcat((2,2), spzeros(Complex128,nx*nz,nx*nz), spzeros(Complex128,nx*nz, 2*nz), spzeros(Complex128,2*nz, nx*nz), E_j)
    end
    for j = 1:nz
        f[j+nz+3] = λ -> S(λ, nz+j)
        e_j = zeros(nz)
        e_j[j] = 1
        E_j = [spzeros(Complex128,nz); R(e_j)]
        E_j = E_j * (E_j/nz)'
        A[j+nz+3] =  hvcat((2,2), spzeros(Complex128,nx*nz,nx*nz), spzeros(Complex128,nx*nz, 2*nz), spzeros(Complex128,2*nz, nx*nz), E_j)
    end
    return SPMF_NEP(A,f,pre_Schur_fact)
end


###########################################################
# Generate R-matrix
# Part of defining the P-matrix, see above, Jarlebring-(1.6) and Ringh-(2.8) and Remark 1
# OBS: R' = nz * Rinv, as noted in Ringh between (2.8) and Remark 1
function generate_R_matvecs(nz::Integer)
    # The scaled FFT-matrix R
    p = (nz-1)/2;
    bb = exp.(-2im*pi*((1:nz)-1)*(-p)/nz);  # scaling to do after FFT
    function R(X) # Note! Only works for vectors or one-dim matrices
        return flipdim(bb .* fft(vec(X)), 1);
    end
    bbinv = 1./bb; # scaling to do before inverse FFT
    function Rinv(X)
        return ifft(bbinv .* flipdim(vec(X),1));
    end
    return R, Rinv
end


###########################################################
# Generate S-function for matrix argument
# Part of defining the P-matrix, see above, Jarlebring-(2.4) and Ringh-(2.8)(2.3)
function generate_S_function(nz::Integer, hx, Km, Kp)
    # Constants from the problem
    p = (nz-1)/2;
    d0 = -3/(2*hx);
    b = 4*pi*1im * (-p:p);
    cM = Km^2 - 4*pi^2 * ((-p:p).^2);
    cP = Kp^2 - 4*pi^2 * ((-p:p).^2);

    # Note: γ should be scalar or matrix (not vector)
    betaM = function(γ, j::Integer)
        return γ^2 + b[j]*γ + cM[j]*eye(Complex128,size(γ,1))
    end
    betaP = function(γ, j::Integer)
        return γ^2 + b[j]*γ + cP[j]*eye(Complex128,size(γ,1))
    end

    sM = function(γ, j::Integer)
        return  1im*sqrtm_schur_pos_imag(betaM(γ, j)) + d0*eye(Complex128, size(γ,1))
    end
    sP = function(γ, j::Integer)
        return  1im*sqrtm_schur_pos_imag(betaP(γ, j)) + d0*eye(Complex128, size(γ,1))
    end


    S = function(γ, j::Integer)
        if j <= nz
            return sM(γ,j)
        elseif j <= 2*nz
            return sP(γ,(j-nz))
        else
            error("The chosen j = ", j, "but the setup nz = ", nz, ". Hence j>2nz which is illegal.")
        end
    end

    return S
end


###########################################################
    """
    sqrtm_schur_pos_imag(A::AbstractMatrix)
 Computes the matrix square root on the 'correct branch',
 that is, with positivt imaginary part. Similar to Schur method
 in Algorithm 6.3 in Higham matrix functions.
"""
function sqrtm_schur_pos_imag(A::AbstractMatrix)
    n = size(A,1);
    AA = Array{Complex128,2}(A);
    (T, Q, ) = schur(AA)
    U = zeros(Complex128,n,n);
    for i = 1:n
        U[i,i] = sqrt_pos_imag(T[i,i])
    end
    private_inner_loops_sqrt!(n, U, T)
    return Q*U*Q'
end
#Helper function executing the inner loop (more Juliaesque)
function private_inner_loops_sqrt!(n, U, T)
    temp = zero(Complex128);
    for j = 2:n
        for i = (j-1):-1:1
            temp *= zero(Complex128);
            for k = (i+1):(j-1)
                temp += U[i,k]*U[k,j]
            end
            U[i,j] = (T[i,j] - temp)/(U[i,i]+U[j,j])
        end
    end
end

    """
    sqrt_pos_imag(a::Complex128) and sqrt_pos_imag(a::Float64)
 Helper function: Computes the scalar square root on the 'correct branch',
 that is, with positivt imaginary part.
"""
function sqrt_pos_imag(a::Complex128)
    imag_sign = sign(imag(a))
    if imag_sign == 0 #Real value in complex type
        sqrt(a)
    else
        sign(imag(a))*sqrt(a)
    end
end
function sqrt_pos_imag(a::Float64)
    return sqrt(a)
end


###########################################################
# Waveguide eigenvalue problem - WEP
# A more optimized (native) implementation of the WEP with FD discretization
    """
    Waveguide eigenvalue problem
  A more optimized implementation of the WEP for FD-discretization.\\
  Closer to what is done in the article:
    ''E. Ringh, and G. Mele, and J. Karlsson, and E. Jarlebring,
      Sylvester-based preconditioning for the waveguide eigenvalue problem,
      Linear Algebra and its Applications''
"""
    type WEP_FD <: WEP
        nx::Int64
        nz::Int64
        hx::Float64
        hz::Float64
        A::Function
        B::Function
        C1
        C2T
        k_bar
        K
        p::Integer
        d0::Float64
        d1::Float64
        d2::Float64
        b
        cMP # cM followed by cP in a vector (length = 2*nz)
        R::Function
        Rinv::Function
        Pinv::Function
        generate_Pm_and_Pp_inverses::Function

        function WEP_FD(nx, nz, hx, hz, Dxx, Dzz, Dz, C1, C2T, K, Km, Kp)
            n = nx*nz + 2*nz
            k_bar = mean(K)
            K_scaled = K-k_bar*ones(Complex128,nz,nx)

            eye_scratch_pad = speye(Complex128, nz, nz)

            A = function(λ, d=0)
                if(d == 0)
                    return Dzz + 2*λ*Dz + λ^2*eye_scratch_pad + k_bar*eye_scratch_pad
                elseif(d == 1)
                    return 2*Dz + 2*λ*eye_scratch_pad
                elseif(d == 2)
                    return 2*eye_scratch_pad
                else
                    return spzeros(Complex128, nz, nz)
                end
            end
            B = function(λ, d=0)
                if(d == 0)
                    return Dxx
                else
                    return spzeros(Complex128, nx, nx)
                end
            end

            p = (nz-1)/2

            d0 = -3/(2*hx)
            d1 = 2/hx
            d2 = -1/(2*hx)

            b = 4*pi*1im * (-p:p)
            cM = Km^2 - 4*pi^2 * ((-p:p).^2)
            cP = Kp^2 - 4*pi^2 * ((-p:p).^2)
            cMP = vcat(cM, cP)

            R, Rinv = generate_R_matvecs(nz)
            Pinv = generate_Pinv_matrix(nz, hx, Km, Kp)
            generate_Pm_and_Pp_inverses(σ) =  helper_generate_Pm_and_Pp_inverses(nz, b, cMP, d0, R, Rinv, σ)

            this = new(nx, nz, hx, hz, A, B, C1, C2T, k_bar, K_scaled, p, d0, d1, d2, b, cMP, R, Rinv, Pinv, generate_Pm_and_Pp_inverses)
        end
    end


    function size(nep::WEP_FD, dim=-1)
        n = nep.nx*nep.nz + 2*nep.nz
        if (dim==-1)
            return (n,n)
        else
            return n
        end
    end


    function issparse(nep::WEP_FD)
        return false
    end


    #Helper function: Generates function to compute iverse of the boundary operators, Ringh - (2.8)
    #To be used in the Schur-complement- and SMW-context.
    function helper_generate_Pm_and_Pp_inverses(nz, b, cMP, d0, R, Rinv, σ)
        # S_k(σ) + d_0, as in Ringh - (2.3a)
        coeffs = zeros(Complex128, 2*nz)
            aa = 1.0
        for j = 1:2*nz
            bb = b[rem(j-1,nz)+1]
            cc = cMP[j]
            coeffs[j] = 1im*sqrt_derivative(aa, bb, cc, 0, σ) + d0
        end

        # P_inv_m and P_inv_p, the boundary operators
        P_inv_m = function(v)
            return R(Rinv(v) ./ coeffs[1:nz])
        end
        P_inv_p = function(v)
            return R(Rinv(v) ./ coeffs[(nz+1):(2*nz)])
        end

        return P_inv_m, P_inv_p
    end


    """
    compute_Mlincomb(nep::WEP_FD, λ::Number, V; a=ones(Complex128,size(V,2)))
Specialized for Waveguide Eigenvalue Problem discretized with Finite Difference\\\\
 Computes the linear combination of derivatives\\
 ``Σ_i a_i M^{(i)}(λ) v_i``
"""
    function compute_Mlincomb(nep::WEP_FD, λ::Number, V;
                              a=ones(Complex128,size(V,2)))
        na = size(a,1)
        nv = size(V,1)
        mv = size(V,2)
        n_nep = size(nep,1)
        if(na != mv)
            error("Incompatible sizes: Number of coefficients = ", na, ", number of vectors = ", mv, ".")
        end
        if(nv != n_nep)
            error("Incompatible sizes: Length of vectors = ", nv, ", size of NEP = ", n_nep, ".")
        end
        nx = nep.nx
        nz = nep.nz
        max_d = na - 1 #Start on 0:th derivative

        V1 = view(V, 1:nx*nz, :)
        V1_mat = reshape(V1, nz, nx, na)
        V2 = view(V, nx*nz+1:n_nep, :)

        # Compute the top part (nx*nz)
        y1_mat::Array{Complex128,2} = (nep.A(λ) * V1_mat[:,:,1] + V1_mat[:,:,1] * nep.B(λ)  +  nep.K .* V1_mat[:,:,1])*a[1]
        for d = 1:min(max_d,3)
            y1_mat += nep.A(λ,d) * V1_mat[:,:,d+1] * a[d+1];
        end
        y1::Array{Complex128,1} = y1_mat[:]
        y1 += nep.C1 * V2[:,1] * a[1]

        # Compute the bottom part (2*nz)
        D::Array{Complex128,2} = zeros(Complex128, 2*nz, na)
        for j = 1:2*nz
            aa = 1
            bb = nep.b[rem(j-1,nz)+1]
            cc = nep.cMP[j]
            der_coeff = 1im*sqrt_derivative(aa, bb, cc, max_d, λ)
            for jj = 1:na
                D[j, jj] = der_coeff[jj]
            end
        end
        
        #Multpilication with diagonal matrix optimized by working "elementwise" Jarlebring-(4.6)
        y2_temp::Array{Complex128,1} =
            (D[:,1] + nep.d0) .* [nep.Rinv(V2[1:nz,1]);
                                  nep.Rinv(V2[nz+1:2*nz,1])]*a[1]
        
        for jj = 2:na
            #Multpilication with diagonal matrix optimized by working "elementwise" Jarlebring-(4.6)
            y2_temp += D[:,jj] .* [nep.Rinv(V2[1:nz,jj]);
                                   nep.Rinv(V2[nz+1:2*nz,jj])] *a[jj]
        end
        y2::Array{Complex128,1} = [nep.R(y2_temp[1:nz,1]);
                                   nep.R(y2_temp[nz+1:2*nz,1])]
        y2 += nep.C2T * V1[:,1]*a[1] #Action of C2T. OBS: Add last because of implcit storage in R*D_i*R^{-1}*v_i

        return vcat(y1, y2)
    end


###########################################################
# Linear Solvers for WEP

    # Matrix vector operations for the Schur complement (to be used in GMRES call)
    # Matrix-vector product according to Ringh (2.13) and (3.3)
    type SchurMatVec
        nep::WEP_FD
        λ::Complex128
        SchurMatVec(nep::WEP_FD, λ::Union{Complex128,Float64}) = new(nep, λ)
    end

    function *(M::SchurMatVec,v::AbstractVector)
        λ = M.λ
        nep = M.nep

        X = reshape(v, nep.nz, nep.nx)
        return vec(  vec( nep.A(λ)*X + X*nep.B(λ) + nep.K.*X ) - nep.C1 * nep.Pinv(λ, nep.C2T*v)  )
    end

    function (M::SchurMatVec)(v::AbstractVector) #Overload the ()-function so that a SchurMatVec struct can act and behave like a function
        return M*v
    end

    function size(M::SchurMatVec, dim=-1)
        n = M.nep.nx*M.nep.nz
        if (dim==-1)
            return (n,n)
        else
            return n
        end
    end

    function eltype(M::SchurMatVec)
        return Complex128
    end


    # GMRES Solver
    type WEPGMRESLinSolver<:LinSolver
        schur_comp::LinearMap{Complex128}
        kwargs
        gmres_log::Bool
        nep::WEP_FD
        λ::Complex128

        function WEPGMRESLinSolver(nep::WEP_FD,λ::Union{Complex128,Float64},kwargs)
            f = SchurMatVec(nep, λ)
            schur_comp = LinearMap{Complex128}(f, nep.nx*nep.nz, ismutating=false, issymmetric=false, ishermitian=false);
            gmres_log = false
            for elem in kwargs
                gmres_log |= ((elem[1] == :log) && elem[2])
            end
            return new(schur_comp, kwargs, gmres_log,nep,λ)
        end
    end

    function WEP_inner_lin_solve(solver::WEPGMRESLinSolver, rhs::Array, tol)
        if( solver.gmres_log )
            q, convhist = gmres(solver.schur_comp, rhs; tol=tol, solver.kwargs...)
        else
            q = gmres(solver.schur_comp, rhs; tol=tol, solver.kwargs...)
        end
        return q
    end

    function wep_gmres_linsolvercreator(nep::WEP_FD, λ, kwargs=())
        return WEPGMRESLinSolver(nep, λ, kwargs)
    end


    # Direct Backslash solver
    type WEPBackslashLinSolver<:LinSolver
        schur_comp::SparseMatrixCSC{Complex128,Int64}
        nep::WEP_FD
        λ::Complex128

        function WEPBackslashLinSolver(nep::WEP_FD, λ::Union{Complex128,Float64}, kwargs=())
            schur_comp = construct_WEP_schur_complement(nep, λ)
            return new(schur_comp, nep, λ)
        end
    end

    function WEP_inner_lin_solve(solver::WEPBackslashLinSolver, rhs::Array, tol)
        return solver.schur_comp \ rhs
    end

    function wep_backslash_linsolvercreator(nep::WEP_FD, λ, kwargs=())
        return WEPBackslashLinSolver(nep, λ, kwargs)
    end


    # Direct pre-factorized solver
    type WEPFactorizedLinSolver<:LinSolver
        schur_comp_fact
        nep::WEP_FD
        λ::Complex128

        function WEPFactorizedLinSolver(nep::WEP_FD, λ::Union{Complex128,Float64}, kwargs=())
            schur_comp_fact = factorize(construct_WEP_schur_complement(nep, λ))
            return new(schur_comp_fact, nep, λ)
        end
    end

    function WEP_inner_lin_solve(solver::WEPFactorizedLinSolver, rhs::Array, tol)
        return solver.schur_comp_fact \ rhs
    end

    function wep_factorized_linsolvercreator(nep::WEP_FD, λ, kwargs=())
        return WEPFactorizedLinSolver(nep, λ, kwargs)
    end


    # Helper functions for WEP LinSolvers. To avoid code repetition.
    # Assembls the full Schur-complement, used in both Backslash and LU solvers
    function construct_WEP_schur_complement(nep::WEP_FD, λ::Union{Complex128,Float64})
        nz = nep.nz
        nx = nep.nx
        Inz = speye(Complex128,nz,nz)
        Inx = speye(Complex128,nx,nx)

        P_inv_m, P_inv_p = nep.generate_Pm_and_Pp_inverses(λ)
        Pinv_minus = Array{Complex128}(nz,nz)
        Pinv_plus = Array{Complex128}(nz,nz)
        e = zeros(Complex128,nz)
        for i = 1:nz
            e[:] = 0
            e[i] = 1
            Pinv_minus[:,i] = P_inv_m(e)
            Pinv_plus[:,i] = P_inv_p(e)
        end

        E = spzeros(nx,nx)
        E[1,1] = nep.d1/(nep.hx^2)
        E[1,2] = nep.d2/(nep.hx^2)
        EE = spzeros(nx,nx)
        EE[nx,nx] = nep.d1/(nep.hx^2)
        EE[nx,nx-1] = nep.d2/(nep.hx^2)

        # Kronecker product form of Ringh - Proposition 3.1
        return kron(nep.B(λ)', Inz) + kron(Inx, nep.A(λ)) + spdiagm(nep.K[:]) - kron(E, Pinv_minus) - kron(EE, Pinv_plus)
    end

    # lin_solve function to wrapp all the WEP linear solvers.
    # Since Schur-complement transformations are the same.
    # Does transforming between that and the full system.
    # Ringh - Proposition 2.1, see also Algorithm 2, step 10-11.
    function lin_solve(solver::Union{WEPBackslashLinSolver,WEPGMRESLinSolver,WEPFactorizedLinSolver}, x::Array; tol=eps(Float64))
    # Ringh - Proposition 2.1
        λ = solver.λ
        nep = solver.nep

        x_int = x[1:(nep.nx*nep.nz)]
        x_ext = x[((nep.nx*nep.nz)+1):((nep.nx*nep.nz) + 2*nep.nz)]
        rhs =  vec(  x_int - nep.C1*nep.Pinv(λ, x_ext))

        q = WEP_inner_lin_solve(solver, rhs, tol)

        return [q; vec(nep.Pinv(λ, -nep.C2T * q + x_ext))]

    end

    # Overloads Defalut and Backslash LinSolvers
    DefaultLinSolver(nep::WEP_FD, λ)   = WEPFactorizedLinSolver(nep, λ)
    BackslashLinSolver(nep::WEP_FD, λ) = WEPBackslashLinSolver(nep, λ)


###########################################################
# Generate a function for mat-vecs with P^{-1}-matrix
# P is the lower right part of the system matrix, from the DtN maps Jarlebring-(1.5)(1.6) and Ringh-(2.4)(2.8)
function generate_Pinv_matrix(nz::Integer, hx, Km, Kp)

    R, Rinv = generate_R_matvecs(nz::Integer)
    p = (nz-1)/2;

    # Constants from the problem
    d0 = -3/(2*hx);
    a = ones(Complex128,nz);
    b = 4*pi*1im * (-p:p);
    cM = Km^2 - 4*pi^2 * ((-p:p).^2);
    cP = Kp^2 - 4*pi^2 * ((-p:p).^2);


    function betaM(γ)
        return a*γ^2 + b*γ + cM
    end
    function betaP(γ)
        return a*γ^2 + b*γ + cP
    end

    function sM(γ::Number)
        bbeta = betaM(γ)
        return 1im*sign.(imag(bbeta)).*sqrt.(bbeta)+d0;
    end
    function sP(γ::Number)
        bbeta = betaP(γ)
        return 1im*sign.(imag(bbeta)).*sqrt.(bbeta)+d0;
    end

    # BUILD THE INVERSE OF THE FOURTH BLOCK P
    function P(γ,x::Union{Array{Complex128,1}, Array{Float64,1}})
        return vec(  [R(Rinv(x[1:Int64(end/2)]) ./ sM(γ));
                      R(Rinv(x[Int64(end/2)+1:end]) ./ sP(γ))  ]  )
    end


    return P
end


###########################################################
#Square root of second degree polynomial (Gegenbauer polynomials)
#Jarlebring - Appendix C
    """
    sqrt_derivative(a,b,c, d=0, x=0)
 Computes all d derivatives of sqrt(a*z^2 + b*z + c)
 in the point z = x.
 Returns a d+1 vector with all numerical values
"""
function sqrt_derivative(a,b,c, d=0, x=0)
    if(d<0)
        error("Cannot take negative derivative. d = ", d)
    end

    aa = a
    bb = b + 2*a*x
    cc = c + a*x^2 + b*x

    derivatives = zeros(Complex128,d+1)

    yi = sqrt_pos_imag(cc)
    derivatives[1] = yi
    if( d==0 )
        return derivatives[1] #OBS: If only function is sought, return it as an integer and not array
    end

    yip1 = bb/(2*sqrt_pos_imag(cc))
    fact = Float64(1)
    derivatives[2] = yip1 * fact
    if( d==1 )
        return derivatives
    end

    yip2 = zero(Complex128)
    for i = 2:d
        m = i - 2
        yip2 = - (2*aa*(m-1)*yi  +  bb*(1+2*m)*yip1) / (2*cc*(2+m))
        fact *= i

        yi = yip1
        yip1 = yip2

        derivatives[i+1] = yip2 * fact
    end
    return derivatives
end

