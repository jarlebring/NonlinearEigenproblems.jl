  """
  Module containing a gallery of examples of nonlinear eigenvalue problems.\\
  Look at the function 'nep_gallery()' for further instructions.
  """
module Gallery
    using NEPCore
    using NEPTypes
    using PolynomialRoots
    using MAT

    export nep_gallery

    push!(LOAD_PATH, string(@__DIR__, "/gallery_extra")) # Add the search-path to the extra galleries



    include("gallery_extra/distributed_example.jl")

  """
     nep=nep_gallery(name)\\
     nep=nep_gallery(name,params)\\
**Returns a NEP object from a gallery of examples of nonlinear eigenvalue problems.**\\
    The parameter 'name' decides which NEP.\\
\\

\\
  **Supported 'name' and 'params':**\\
     'dep0'\\
      Create a random delay eiganvalue problem with one delay tau = 1\\
      * one optional parameter determining the size (default = 5)\\
\\
     'dep0_sparse'\\
      Create a random delay eiganvalue problem with sparse matrices and one delay tau = 1\\
      * one optional parameter determining the size (default = 5)\\
\\
     'dep_double'\\
      Create problem with a double non-semisimple eigenvalue in λ=3πi\\
      Examle from E. Jarlebring, Convergence factors of Newton methods for nonlinear eigenvalue problems, LAA, 2012\\
     'dep1'\\
      A delay eigenvalue problem with one eigenvalue equal to one.\\
\\
     'pep0'\\
     Create a random polynomial eigenvalue problem\\
     * one optional parameter determining the size (default = 200)\\
 \\
      'pep0_sym'\\
      Create a random symmetric polynomial eigenvalue problem\\
      * one optional parameter determining the size (default = 200)\\
\\
     'pep0_sparse_003'\\
     Create a random polynomial eigenvalue problem with sparse matrices with about 3% fill-in
     * one optional parameter determining the size (default = 200)\\
\\
     'real_quadratic'\\
     Create a quadratic problem with real eigenvalues\\
          Four smallest eigenvalues of the problem:\\
          -2051.741417993845\\
          -182.101627437811\\
          -39.344930222838\\
          -4.039879577113\\
\\
     'dep_distributed'\\
     Creates the NEP associated with example in E. Jarlebring and W. Michiels and K. Meerbergen,\\
     The infinite  {Arnoldi} method and an application to time-delay systems with distributed delays,\\
     Delay Systems - Methods, Applications and New Trends, 2012\\
         Some correct eigenvalues:\\
         -0.400236388049641 + 0.970633098237807i\\
         -0.400236388049641 - 0.970633098237807i\\
          2.726146249832675 + 0.000000000000000i\\
         -1.955643591177653 + 3.364550574688863i\\
         -1.955643591177653 - 3.364550574688863i\\
          4.493937056300693 + 0.000000000000000i\\
         -1.631513006819252 + 4.555484848248613i\\
         -1.631513006819252 - 4.555484848248613i\\
         -1.677320660400946 + 7.496870451838560i\\
         -1.677320660400946 - 7.496870451838560i\\

\\
     'qdep0' \\
      Quadratic delay eigenvalue problem in "The infinite Bi-Lanczos method for nonlinear
      eigenvalue problems",  Sarah W. Gaaf and Elias Jarlebring \\
\\

     'qep_fixed_eig'\\
     Create a quadratic eigenvalue problem with chosen eigenvalues
     * two optional parameters determining the size (default = 5)
       and a vector containing the eigenvalues (default = randn)       \\
\\

   **See also the following galleries:**\\
      * GalleryNLEVP\\
      * GalleryWaveguide\\
  """
  nep_gallery(name::String,params...;kwargs...)=nep_gallery(NEP,name,params...;kwargs...)
  function nep_gallery{T<:NEP}(::Type{T},name::String,params...;kwargs...)
      local n
      if (name == "dep0")
          # A delay eigenvalue problem
          if (length(params)>0)
              n=params[1]
          else
              n=5; # Default size
          end

          srand(0) # reset the random seed
          A0=randn(n,n);
          A1=randn(n,n);
          tau=1;
          nep=DEP([A0,A1],[0,tau])
          return nep

      elseif (name == "dep0_sparse")
          # A delay eigenvalue problem with sparse matrices
          if (length(params)>0)
              n=params[1]
          else
              n=5; # Default size
          end
          srand(0) # reset the random seed
          A0=sparse(randn(n,n));
          A1=sparse(randn(n,n));
          tau=1;
          nep=DEP([A0,A1],[0,tau])
          return nep

      elseif (name == "dep_double")
          # A delay eigenvalue problem with a double non-semisimple eigenvalue in λ=3πi
          # Examle from E. Jarlebring, Convergence factors of Newton methods for nonlinear eigenvalue problems, LAA, 2012
          n=3;

          denom = 8+5*pi;
          a1 = 2/5 *(65*pi + 32)/(denom);
          a2 = 9*pi^2*(13+5*pi)/(denom);
          a3 = 324/5 *pi^2*(5*pi+4)/(denom);
          b1 = (260*pi + 128 + 225*pi^2)/(10*denom);
          b2 = 45*pi^2/denom;
          b3 = 81*pi^2*(40*pi + 32 + 25*pi^2)/(10*denom);
          A0 = [ 0    1    0;  0    0    1;  -a3  -a2  -a1];
          A1 = [ 0    0    0;  0    0    0;  -b3  -b2  -b1];

          tau=1;
          nep=DEP([A0,A1],[0,tau])
          return nep

      elseif (name== "pep0")
          # A polynomial eigenvalue problem
          if (length(params)>0)
              n=params[1]
          else
              n=200; # Default size
          end

          srand(0)
          A0=randn(n,n)
          A1=randn(n,n)
          A2=randn(n,n)
          A=[A0,A1,A2]
          nep=PEP(A)
          return nep

      elseif (name== "pep0_sym")
          # A polynomial eigenvalue problem
          if (length(params)>0)
              n=params[1]
          else
              n = 200; # Default size
          end

          srand(0)
          A0 = Symmetric(randn(n,n))
          A1 = Symmetric(randn(n,n))
          A2 = Symmetric(randn(n,n))
          A = [A0]#, A1, A2]
          nep = PEP(A)
          return nep

      elseif (name== "pep0_sparse_003")
          # A sparse polynomial eigenvalue problem
          if (length(params)>0)
              n=params[1]
          else
              n=200; # Default size
          end

          srand(0)
          A0=sprandn(n,n,0.03)
          A1=sprandn(n,n,0.03)
          A2=sprandn(n,n, 0.03)
          A=[A0,A1,A2]
          nep=PEP(A)
          return nep

      elseif (name== "real_quadratic")
          # Create a quadratic problem with real eigenvalues
          n=4; # mat size

	  A0 = [4     0     1     1;
    		0     2     1     1;
   		1     1     6    -2;
    		1     1    -2     3];


	A1 = [167  -140    95  -131;
	     -140   327    54    85;
 	       95    54   235   -81;
 	     -131    85   -81   181];


	A2 =  [2     1    -1    -1;
  	       1     5    -3     2;
  	      -1    -3     3     0;
	      -1     2     0     3];

	# Four smallest eigenvalues of the problem:
	# 1.0e+03 *
	# -2.051741417993845
  	# -0.182101627437811
  	# -0.039344930222838
  	# -0.004039879577113


          A=[A0,A1,A2]
          nep=PEP(A)
          return nep
      elseif (name=="dep1")
          A0=([1 2 3 ; 4 5 6; 1 -1 3]);
          A1=((-A0+[1 0 3;0 0 -1;0 0 10])*exp(1));
          Q=[1 0 3; 1 1 -4; 2 3 1];
          A0=Q\(A0*Q);
          A1=Q\(A1*Q);
          nep=DEP([A0,A1],[0,1])
          return nep;

      elseif (name== "dep_distributed")
          return gallery_dep_distributed();

      elseif (name=="qdep0")

          qdepfile=joinpath(dirname(@__FILE__()),
                            "gallery_extra","qdep_infbilanczos.mat")
          file=matopen(qdepfile);
          A0=read(file,"A0");
          A1=read(file,"A1");
          close(file)
          tau=1;
          quadfun= S -> S^2;
          constfun= S -> eye(S);
          expfun= S -> expm(-tau*full(S));

          AA=[-speye(A0),A0,A1]
          fi=[quadfun,constfun,expfun]
          return SPMF_NEP(AA,fi)

      elseif (name == "qep_fixed_eig")
          # A delay eigenvalue problem
          if (length(params)>0)
            n=params[1]
          else
            n=5; # Default size
          end

          if (length(params)>1)
            E=params[2]
          else
            E=randn(2*n)
          end


          srand(0) # reset the random seed
          I=eye(n);
          A1=diagm(E[1:n]);
          A2=diagm(E[n+1:2*n]);

          nep=PEP([A1*A2,-A1-A2,I])
          return nep

      else
          error("The name '", name, "' is not supported in NEP-Gallery.")
      end

  end



end
